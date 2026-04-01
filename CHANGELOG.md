# Hanami::Mailer
Mail for Ruby applications

## v2.0.0.alpha1 - 2024-XX-XX
### Changed
- Complete rewrite of Hanami::Mailer for Hanami 2.0
- Simplified DSL for defining mailers
- Replaced template system with Hanami::View 2.x integration
- New exposure system borrowed from Hanami::View for consistent data preparation
- Pluggable delivery methods with cleaner API
- Removed dependency on hanami-utils and tilt
- Drop support for Ruby: MRI 2.3, 2.4, 2.5, 2.6
- Minimum Ruby version: 3.0

### Added
- `Hanami::Mailer::Message` - immutable email message representation
- `Hanami::Mailer::Delivery::Test` - in-memory delivery for testing
- `Hanami::Mailer::Delivery::Smtp` - SMTP delivery method
- Exposure system with dependency resolution and topological sorting
- Support for static and dynamic attachments
- Support for inline attachments with content IDs
- Multiple attachments per mailer
- `expose` DSL for defining template data
- `attachment` DSL for defining email attachments
- Improved inheritance support for mailers
- Configuration via `Dry::Configurable`
- `prepare` method to build messages without delivering
- `default_from` configuration option
- `default_charset` configuration option

### Removed
- Global configuration class `Hanami::Mailer::Configuration`
- Configuration finalization requirement
- `before` callbacks (use exposures and regular methods instead)
- Template inference from mailer class name (use Hanami::View integration)
- `template` DSL method
- Direct template rendering without view integration
- Dependency on `hanami-utils`
- Dependency on `tilt`
- `return_path` DSL method (can be added via custom headers if needed)

### Fixed
- Thread-safety improvements
- Better error messages for missing configuration

## v1.3.3 - 2021-01-14
### Added
- [Luca Guidi] Official support for Ruby: MRI 3.0

## v1.3.2 - 2020-02-03
### Added
- [Luca Guidi] Official support for Ruby: MRI 2.7
- [glaszig] Added `Hanami::Mailer.return_path` and `#return_path` to specify `MAIL FROM` address

## v1.3.1 - 2019-01-18
### Added
- [Luca Guidi] Official support for Ruby: MRI 2.6
- [Luca Guidi] Support `bundler` 2.0+

## v1.3.0 - 2018-10-24
### Added
- [Ben Bachhuber] Added support for `reply_to`

## v1.3.0.beta1 - 2018-08-08
### Added
- [Luca Guidi] Official support for JRuby 9.2.0.0

## v1.2.0 - 2018-04-11

## v1.2.0.rc2 - 2018-04-06

## v1.2.0.rc1 - 2018-03-30

## v1.2.0.beta2 - 2018-03-23

## v1.2.0.beta1 - 2018-02-28
### Added
- [Luca Guidi] Official support for Ruby: MRI 2.5

## v1.1.0 - 2017-10-25

## v1.1.0.rc1 - 2017-10-16

## v1.1.0.beta3 - 2017-10-04

## v1.1.0.beta2 - 2017-10-03

## v1.1.0.beta1 - 2017-08-11

## v1.0.0 - 2017-04-06

## v1.0.0.rc1 - 2017-03-31
### Fixed
- [Luca Guidi] Let `Hanami::Mailer.deliver` to bubble up `ArgumentError` exceptions

## v1.0.0.beta2 - 2017-03-17

## v1.0.0.beta1 - 2017-02-14
### Added
- [Luca Guidi] Official support for Ruby: MRI 2.4

## v0.4.0 - 2016-11-15
### Changed
- [Luca Guidi] Official support for Ruby: MRI 2.3+ and JRuby 9.1.5.0+

## v0.3.0 - 2016-07-22
### Added
- [Anton Davydov] Blind carbon copy (bcc) option
- [Anton Davydov] Carbon copy (cc) option

### Changed
- [Luca Guidi] Drop support for Ruby 2.0 and 2.1

## v0.2.0 - 2016-01-22
### Changed
- [Luca Guidi] Renamed the project

## v0.1.0 - 2015-09-30
### Added
- [Ines Coelho & Rosa Faria & Luca Guidi] Email delivery
- [Ines Coelho & Rosa Faria & Luca Guidi] Attachments
- [Ines Coelho & Rosa Faria & Luca Guidi] Multipart rendering
- [Ines Coelho & Rosa Faria & Luca Guidi] Configuration
- [Ines Coelho & Rosa Faria & Luca Guidi] Official support for Ruby 2.0
