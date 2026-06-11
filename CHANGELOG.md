# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Break Versioning](https://www.taoensso.com/break-versioning).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

[Unreleased]: https://github.com/hanami/hanami-mailer/compare/v3.0.0.rc1...main

## [3.0.0.rc1]

### Changed

- Rewrite the gem. (@timriley)
- Require Ruby 3.3 or newer.

[3.0.0.rc1]: https://github.com/hanami/hanami-mailer/compare/v1.3.3...v3.0.0.rc1

## [1.3.3] - 2021-01-14

### Added

- Official support for Ruby: MRI 3.0. (Luca Guidi)

[1.3.3]: https://github.com/hanami/hanami-mailer/compare/v1.3.2...v1.3.3

## [1.3.2] - 2020-02-03

### Added

- Official support for Ruby: MRI 2.7. (Luca Guidi)
- Added `Hanami::Mailer.return_path` and `#return_path` to specify `MAIL FROM` address. (glaszig)

[1.3.2]: https://github.com/hanami/hanami-mailer/compare/v1.3.1...v1.3.2

## [1.3.1] - 2019-01-18

### Added

- Official support for Ruby: MRI 2.6. (Luca Guidi)
- Support `bundler` 2.0+. (Luca Guidi)

[1.3.1]: https://github.com/hanami/hanami-mailer/compare/v1.3.0...v1.3.1

## [1.3.0] - 2018-10-24

### Added

- Added support for `reply_to`. (Ben Bachhuber)

[1.3.0]: https://github.com/hanami/hanami-mailer/compare/v1.3.0.beta1...v1.3.0

## [1.3.0.beta1] - 2018-08-08

### Added

- Official support for JRuby 9.2.0.0. (Luca Guidi)

[1.3.0.beta1]: https://github.com/hanami/hanami-mailer/compare/v1.2.0...v1.3.0.beta1

## [1.2.0] - 2018-04-11

[1.2.0]: https://github.com/hanami/hanami-mailer/compare/v1.2.0.rc2...v1.2.0

## [1.2.0.rc2] - 2018-04-06

[1.2.0.rc2]: https://github.com/hanami/hanami-mailer/compare/v1.2.0.rc1...v1.2.0.rc2

## [1.2.0.rc1] - 2018-03-30

[1.2.0.rc1]: https://github.com/hanami/hanami-mailer/compare/v1.2.0.beta2...v1.2.0.rc1

## [1.2.0.beta2] - 2018-03-23

[1.2.0.beta2]: https://github.com/hanami/hanami-mailer/compare/v1.2.0.beta1...v1.2.0.beta2

## [1.2.0.beta1] - 2018-02-28

### Added

- Official support for Ruby: MRI 2.5. (Luca Guidi)

[1.2.0.beta1]: https://github.com/hanami/hanami-mailer/compare/v1.1.0...v1.2.0.beta1

## [1.1.0] - 2017-10-25

[1.1.0]: https://github.com/hanami/hanami-mailer/compare/v1.1.0.rc1...v1.1.0

## [1.1.0.rc1] - 2017-10-16

[1.1.0.rc1]: https://github.com/hanami/hanami-mailer/compare/v1.1.0.beta3...v1.1.0.rc1

## [1.1.0.beta3] - 2017-10-04

[1.1.0.beta3]: https://github.com/hanami/hanami-mailer/compare/v1.1.0.beta2...v1.1.0.beta3

## [1.1.0.beta2] - 2017-10-03

[1.1.0.beta2]: https://github.com/hanami/hanami-mailer/compare/v1.1.0.beta1...v1.1.0.beta2

## [1.1.0.beta1] - 2017-08-11

[1.1.0.beta1]: https://github.com/hanami/hanami-mailer/compare/v1.0.0...v1.1.0.beta1

## [1.0.0] - 2017-04-06

[1.0.0]: https://github.com/hanami/hanami-mailer/compare/v1.0.0.rc1...v1.0.0

## [1.0.0.rc1] - 2017-03-31

### Fixed

- Let `Hanami::Mailer.deliver` to bubble up `ArgumentError` exceptions. (Luca Guidi)

[1.0.0.rc1]: https://github.com/hanami/hanami-mailer/compare/v1.0.0.beta2...v1.0.0.rc1

## [1.0.0.beta2] - 2017-03-17

[1.0.0.beta2]: https://github.com/hanami/hanami-mailer/compare/v1.0.0.beta1...v1.0.0.beta2

## [1.0.0.beta1] - 2017-02-14

### Added

- Official support for Ruby: MRI 2.4. (Luca Guidi)

[1.0.0.beta1]: https://github.com/hanami/hanami-mailer/compare/v0.4.0...v1.0.0.beta1

## [0.4.0] - 2016-11-15

### Changed

- Official support for Ruby: MRI 2.3+ and JRuby 9.1.5.0+. (Luca Guidi)

[0.4.0]: https://github.com/hanami/hanami-mailer/compare/v0.3.0...v0.4.0

## [0.3.0] - 2016-07-22

### Added

- Blind carbon copy (bcc) option. (Anton Davydov)
- Carbon copy (cc) option. (Anton Davydov)

### Changed

- Drop support for Ruby 2.0 and 2.1. (Luca Guidi)

[0.3.0]: https://github.com/hanami/hanami-mailer/compare/v0.2.0...v0.3.0

## [0.2.0] - 2016-01-22

### Changed

- Renamed the project. (Luca Guidi)

[0.2.0]: https://github.com/hanami/hanami-mailer/compare/v0.1.0...v0.2.0

## [0.1.0] - 2015-09-30

### Added

- Email delivery. (Ines Coelho & Rosa Faria & Luca Guidi)
- Attachments. (Ines Coelho & Rosa Faria & Luca Guidi)
- Multipart rendering. (Ines Coelho & Rosa Faria & Luca Guidi)
- Configuration. (Ines Coelho & Rosa Faria & Luca Guidi)
- Official support for Ruby 2.0. (Ines Coelho & Rosa Faria & Luca Guidi)

[0.1.0]: https://github.com/hanami/hanami-mailer/releases/tag/v0.1.0
