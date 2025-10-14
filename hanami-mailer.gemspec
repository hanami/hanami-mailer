# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hanami/mailer/version"

Gem::Specification.new do |spec|
  spec.name          = "hanami-mailer"
  spec.version       = Hanami::Mailer::VERSION
  spec.authors       = ["Hanami team"]
  spec.email         = ["admin@hanamirb.org"]

  spec.summary       = "Mail for Ruby applications."
  spec.description   = "Mail for Ruby applications and Hanami mailers"
  spec.homepage      = "http://hanamirb.org"
  spec.license       = "MIT"

  spec.files = Dir["*.gemspec", "lib/**/*"]

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/hanami/hanami-mailer/issues",
    "changelog_uri" => "https://github.com/hanami/hanami-mailer/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://guides.hanamirb.org",
    "funding_uri" => "https://github.com/sponsors/hanami",
    "source_code_uri" => "https://github.com/hanami/hanami-mailer",
    "rubygems_mfa_required" => "true"
  }

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "hanami-utils", ">= 2.3.0.beta1"
  spec.add_dependency "tilt",         "~> 2.0", ">= 2.0.1"
  spec.add_dependency "mail",         "~> 2.8.1"
  spec.add_dependency "dry-configurable", "~> 1.0", "< 2"
  spec.add_dependency "zeitwerk", "~> 2.6"

  spec.add_development_dependency "bundler", ">= 1.6", "< 3"
  spec.add_development_dependency "rake",    "~> 13"
  spec.add_development_dependency "rspec",   "~> 3.9"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
