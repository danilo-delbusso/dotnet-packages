# Copyright (c) Citrix Systems, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms,
# with or without modification, are permitted provided
# that the following conditions are met:
#
# *   Redistributions of source code must retain the above
#     copyright notice, this list of conditions and the
#     following disclaimer.
# *   Redistributions in binary form must reproduce the above
#     copyright notice, this list of conditions and the
#     following disclaimer in the documentation and/or other
#     materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# Note: this build does not sign the binaries
# It's up to the consumer of the binaries to sign them

# NOTE: do not remove the Requires directive
#Requires -Version 3.0

Param(
  [Parameter(Mandatory = $false, HelpMessage = "Key for applying strong names to the assemblies")]
  [String]$SnkKey,
  [Parameter(Mandatory = $true, HelpMessage = "Package source for NuGet restores.")]
  [String]$NugetSource
)

$ErrorActionPreference = 'Stop'

function mkdirClean ([String[]] $paths) {
  foreach ($path in $paths) {
    if (Test-Path $path) {
      Remove-Item -Recurse -Force $path
    }
    New-Item -ItemType "directory" -Path "$path" | Out-Null
  }
}

function applyPatch {
  Param(
    [Parameter(Mandatory = $true)][String]$Path,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$Patch
  )

  process {
    Write-Output "Applying patch file $patch..."
    patch -b --binary -d $Path -p0 -i $Patch

    if (-not $?) {
        Write-Error "Failed to apply $Patch"
    }
  }
}

$SWITCHES = '/nologo', '/m', '/verbosity:normal', '/p:Configuration=Release', `
            '/p:DebugSymbols=true', '/p:DebugType=pdbonly'
$FRAME48 = '/p:TargetFrameworkVersion=v4.8'
$VS2019 = '/toolsversion:Current'

if ($SnkKey) {
  $SIGN = '/p:SignAssembly=true', "/p:AssemblyOriginatorKeyFile=$SnkKey"
}

$REPO = Get-Item "$PSScriptRoot" | select -ExpandProperty FullName
$BUILD_DIR = "$REPO\_build"
$SCRATCH_DIR = "$BUILD_DIR\scratch"
$OUTPUT_DIR = "$BUILD_DIR\output"
$RESTORE_NUGET_CONFIG_FILE="$REPO\NuGet.Config"
$PATCHES = "$REPO\patches"

$RESTORE_SWITCHES= '/restore', '/p:RestoreNoCache=true', "-p:RestoreConfigFile=$RESTORE_NUGET_CONFIG_FILE"

# Replace public NuGet URL
((Get-Content -path $RESTORE_NUGET_CONFIG_FILE -Raw) -replace 'https://api.nuget.org/v3/index.json', $NugetSource) |`
 Set-Content -Path $RESTORE_NUGET_CONFIG_FILE


try {
  if(Get-Command dotnet){
    Write-Output 'DEBUG: Printing MSBuild.exe version...'
    dotnet msbuild --version
    Write-Output ''
  }
}
catch {
  Write-Host "Could not find the dotnet command. Ensure you have installed the dotnet CLI"
  return
}


mkdirClean $BUILD_DIR, $SCRATCH_DIR, $OUTPUT_DIR

#prepare sources and manifest

Set-Location -Path $REPO
$gitCommit = git rev-parse HEAD
git archive --format=zip -o "$OUTPUT_DIR\\dotnet-packages-sources.zip" $gitCommit
"dotnet-packages.git $gitCommit" | Out-File -FilePath "$OUTPUT_DIR\dotnet-packages-manifest.txt"

#prepare xml-rpc dotnet 4.8

mkdirClean "$SCRATCH_DIR\xml-rpc_v48.net"
Expand-Archive -DestinationPath "$SCRATCH_DIR\xml-rpc_v48.net" -Path "$REPO\XML-RPC.NET\xml-rpc.net.2.5.0.zip"

Get-ChildItem $PATCHES | where { $_.Name.StartsWith("patch-xmlrpc") -and !$_.Name.Contains("dotnet45") } |`
  % { $_.FullName } | applyPatch -Path "$SCRATCH_DIR\xml-rpc_v48.net"

dotnet msbuild $SWITCHES $RESTORE_SWITCHES $FRAME48 $VS2019 $SIGN "$SCRATCH_DIR\xml-rpc_v48.net\src\xmlrpc.csproj"

dotnet pack "$SCRATCH_DIR\xml-rpc_v48.net\src\xmlrpc.csproj" --output "$SCRATCH_DIR\xml-rpc_v48.net\bin" --no-build `
  /p:Configuration=Release `
  /verbosity:normal

Move-Item "$SCRATCH_DIR\xml-rpc_v48.net\bin\CookComputing.XmlRpcV2.XS.5.0.1.nupkg" -Destination $OUTPUT_DIR

# prepare Json.NET 4.5, 4.8, and .NET Standard 2.0

mkdirClean "$SCRATCH_DIR\json.net"
Expand-Archive -DestinationPath "$SCRATCH_DIR\json.net" -Path "$REPO\Json.NET\Newtonsoft.Json-13.0.1.zip"
Move-Item "$SCRATCH_DIR\json.net\Newtonsoft.Json-13.0.1\Src\Newtonsoft.Json" "$SCRATCH_DIR\json.net"
Move-Item "$SCRATCH_DIR\json.net\Newtonsoft.Json-13.0.1\LICENSE.md" "$SCRATCH_DIR\json.net"

Get-ChildItem $PATCHES | where { $_.Name.StartsWith("patch-json-net")} |`
  % { $_.FullName } | applyPatch -Path "$SCRATCH_DIR\json.net"

dotnet msbuild $SWITCHES $RESTORE_SWITCHES $VS2019 $SIGN "$SCRATCH_DIR\json.net\Newtonsoft.Json\Newtonsoft.Json.csproj"

dotnet pack "$SCRATCH_DIR\json.net\Newtonsoft.Json\Newtonsoft.Json.csproj" --output "$SCRATCH_DIR\json.net\Newtonsoft.Json\bin\Release" --no-build `
  /p:Configuration=Release `
  /verbosity:normal

Move-Item "$SCRATCH_DIR\json.net\Newtonsoft.Json\bin\Release\Newtonsoft.Json.CH.13.0.1-beta2.nupkg" -Destination $OUTPUT_DIR

#prepare sharpziplib

mkdirClean "$SCRATCH_DIR\sharpziplib"
Expand-Archive -DestinationPath "$SCRATCH_DIR\sharpziplib" -Path "$REPO\SharpZipLib\SharpZipLib_0854_SourceSamples.zip"

Get-ChildItem $PATCHES | where { $_.Name.StartsWith("patch-sharpziplib") } | % { $_.FullName } |`
  applyPatch -Path "$SCRATCH_DIR\sharpziplib"

dotnet msbuild $SWITCHES $RESTORE_SWITCHES $FRAME48 $VS2019 $SIGN "$SCRATCH_DIR\sharpziplib\src\ICSharpCode.SharpZLib.csproj"

dotnet pack "$SCRATCH_DIR\sharpziplib\src\ICSharpCode.SharpZLib.csproj" --output "$SCRATCH_DIR\sharpziplib\bin\" --no-build `
  /p:Configuration=Release `
  /verbosity:normal

Move-Item "$SCRATCH_DIR\sharpziplib\bin\ICSharpCode.SharpZipLib.XS.0.85.4.nupkg" -Destination $OUTPUT_DIR

#copy licences

Copy-Item "$REPO\XML-RPC.NET\LICENSE" -Destination "$OUTPUT_DIR\LICENSE.CookComputing.XmlRpcV2.txt"
Copy-Item "$REPO\Json.NET\LICENSE.txt" -Destination "$OUTPUT_DIR\LICENSE.Newtonsoft.Json.txt"
Copy-Item "$REPO\SharpZipLib\LICENSE" -Destination "$OUTPUT_DIR\LICENSE.ICSharpCode.SharpZipLib.txt"