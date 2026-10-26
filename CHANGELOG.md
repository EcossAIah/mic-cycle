# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [1.4.0] - 2026-10-26

### Added

- Open at Login menu toggle. Uses macOS Login Items, so it also shows under
  **System Settings > General > Login Items**.
- DMG installer alongside the zip.
- Homebrew cask (`brew tap EcossAIah/mic-cycle https://github.com/EcossAIah/mic-cycle`).
- Optional Developer ID signing and notarization in the release scripts.

### Changed

- Release build is universal (Apple silicon and Intel).

## [1.3.0] - 2026-10-25

First public release. Versions 1.0.0 to 1.2.0 were private builds.

### Added

- Menu bar list of the inputs that can be the system default, with the current one checked.
- Control+Option+M global shortcut and a Next Microphone menu item to cycle inputs.
- Confirmation panel, shown only after Core Audio reads back the new default.
  Waits up to two seconds for the readback.
- Failure messages that name the requested and actual devices.
- Automatic refresh when devices connect or disconnect, change eligibility,
  or the default input is changed elsewhere.
- Copy Diagnostics menu item.
- `build-app.sh` and `package-release.sh` for building and packaging from source.

[1.3.0]: https://github.com/EcossAIah/mic-cycle/releases/tag/v1.3.0
