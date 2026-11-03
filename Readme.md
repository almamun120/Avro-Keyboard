# Avro Keyboard

Unicode compliant open source Bangla typing software (IME).
Visit: [https://www.omicronlab.com](https://www.omicronlab.com "OmicronLab") for latest version.

## Required Delphi Version

Was tested with **Delphi 12 community edition**

The community edition can be download from here:
https://www.embarcadero.com/products/delphi/starter/free-download

## Poppy Layout

A rule based phonetic layout (see `docs/PoppyLayout.md`). Select it from
**Select keyboard layout → Poppy Layout (Phonetic)**. Engine: `Keyboard and Spell checker/Classes/clsPoppyPhonetic.pas`
(VCL-free, tested by `tests/PoppyTest.pas` against `tests/typing_cases.tsv`).

This build has no update check and no web links (website, forum, social, "on the web" menus).

## Automatic build

`.github/workflows/build.yml` runs the Poppy engine tests on GitHub and builds the Delphi projects on a
self-hosted Windows runner that has Delphi installed (labels: `self-hosted, windows, delphi`). Push a `v*` tag for a release zip.

## Development/Contributing

- Please use project specific code formatting profile

  - Go to `Tools > Options > Language > Formatter` in Delphi IDE
  - Load `Formatter_Profile.config` from the root of this project
  - Please make sure to format the sources using this profile before creating a PR

- Debug logs can be viewed using [DebugView](https://learn.microsoft.com/en-us/sysinternals/downloads/debugview) when `{$Define DebugLog}` compiler directive is set in the `ProjectDefines.inc` file from the root of this project.

## Building Standard and Portable editions

### Compiler Directives

Open `ProjectDefines.inc` file in the root folder of the source.

For building portable edition, add the following line in this file and compile:

    {$Define PortableOn}

For building standard edition, remove the above line from the
file or make it a comment like the following and then compile:

    {.$Define PortableOn}

or,

    //{$Define PortableOn}

### Building Projects

Delphi community edition doesn't come with command line compiler. In order to build projects:

- Run `build-ce.bat`
- Open `WholeProject.groupproj` in Delphi IDE and run `Build All` from the project group
- Built and renamed files will be under `build` directory

## Notable contributions

- [@JayedAhsan](https://github.com/JayedAhsan) (PR [#32](https://github.com/mugli/Avro-Keyboard/pull/32)) - 3rd party dependencies are no longer necessary to compile the source, can be compiled with the latest free Community Edition of Delphi, and perf improvements.

## License

Avro Keyboard is licensed under **MOZILLA PUBLIC LICENSE Version 2.0**. You should receive a copy of the license in LICENSE.txt file with both binaries and source. An online version of the license can be found at: [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/ "https://www.mozilla.org/en-US/MPL/2.0/")
