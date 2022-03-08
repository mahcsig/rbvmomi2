# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
- Add a configurable RbVmomi.logger (#14)

## [3.2.0] - 2021-10-08
### Added
- Add support for vSphere 7.0U3 (#7)

## [3.1.0] - 2021-09-23
### Added
- Add support for vSphere 7.0U2 (#4)

## [3.0.1] - 2021-09-23
### Changed
- Remove WIN32::SSPI (#187)
- Remove WIN32::SSPI usage (#186)
- Add a script to verify vmodl.db from a wsdl file (#177)

### Fixed
- Fix unescaped characters in Datastore URLs (#183)
- Improve #to_json behavior on RbVmomi Objects (#185)

[Unreleased]: https://github.com/ManageIQ/rbvmomi2/compare/v3.2.0...HEAD
[3.2.0]: https://github.com/ManageIQ/rbvmomi2/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/ManageIQ/rbvmomi2/compare/v3.0.1...v3.1.0
[3.0.1]: https://github.com/ManageIQ/rbvmomi2/compare/v3.0.0-1...v3.0.1
