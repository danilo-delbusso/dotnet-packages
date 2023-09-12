# Third-Party Components

This repository contains the source code and patches for the third-party
libraries:

* SharpZipLib (v0.85.4)- a Zip, GZip, Tar and BZip2 library written
  entirely in C# for the .NET platform;
* XML-RPC.NET (v2.5.0) - a library for implementing XML-RPC Services
  and clients in the .NET environment;
* Json.NET (v13.0.1) - a Json framework for .NET.

## 🚨 Releases

[![Create release](https://github.com/danilo-delbusso/dotnet-packages/actions/workflows/release.yml/badge.svg)](https://github.com/danilo-delbusso/dotnet-packages/actions/workflows/release.yml)

This repository generates unsigned releases when a new tag is published. These releases are NOT production ready. They are there as an example, and to ensure the packages can be built.

Releases can be found in [xenadmin/dotnet-packages/releases](https://github.com/xenadmin/dotnet-packages/releases/).

## Contributions

The preferable way to contribute patches is to fork the repository on Github and
then submit a pull request. If for some reason you can't use Github to submit a
pull request, then you may send your patch for review to the
xs-devel@lists.xenserver.org mailing list, with a link to a public git repository
for review. Please see the [CONTRIB](CONTRIB) file for some general guidelines on submitting
changes.

## License

This code is licensed under the BSD 2-Clause license. The individual libraries
are subject to their own licenses, which can be found in the corresponding
directories. Please see the [LICENSE](LICENSE) file for more information.

## How to build `dotnet-packages``

### Prerequisites

1. PowerShell `5` or PowerShell `7`
2. .NET Framework `4.8`
3. .NET SDK `6.0.413`
4. The `dotnet` CLI (usually packaged with the .NET SDK)
5. `git` and `patch` packages. These can be obtained with [Cygwin](https://www.cygwin.com/) or [Chocolatey](https://chocolatey.org).

### Build

The libraries can be built (with patches applied) by opening a PowerShell prompt
in the repo root and running:

```shell
.\build.ps1 [-SnkKey <snk-file>] [-NugetSources <package-sources>]
```