# frozen_string_literal: true

# This file is synced from hanakai-rb/repo-sync. To update it, edit repo-sync.yml.

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hanami/mailer/version"

Gem::Specification.new do |spec|
  spec.name          = "hanami-mailer"
  spec.authors       = ["Hanakai team"]
  spec.email         = ["info@hanakai.org"]
  spec.license       = "MIT"
  spec.version       = Hanami::Mailer::VERSION.dup

  spec.summary       = "Email delivery for Hanami applications and Ruby projects."
  spec.description   = spec.summary
  spec.homepage      = "https://hanamirb.org"
  spec.files         = Dir["CHANGELOG.md", "LICENSE", "README.md", "hanami-mailer.gemspec", "lib/**/*"]
  spec.bindir        = "exe"
  spec.executables   = Dir["exe/*"].map { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = ["README.md", "CHANGELOG.md", "LICENSE"]

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["changelog_uri"]     = "https://github.com/hanami/hanami-mailer/blob/main/CHANGELOG.md"
  spec.metadata["source_code_uri"]   = "https://github.com/hanami/hanami-mailer"
  spec.metadata["bug_tracker_uri"]   = "https://github.com/hanami/hanami-mailer/issues"
  spec.metadata["funding_uri"]       = "https://github.com/sponsors/hanami"

  spec.required_ruby_version = ">= 3.1.0"

  spec.add_runtime_dependency "dry-configurable", "~> 1.0"
  spec.add_runtime_dependency "mail", "~> 2.7"
  spec.add_runtime_dependency "zeitwerk"
end

