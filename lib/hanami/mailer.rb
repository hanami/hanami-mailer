# frozen_string_literal: true

require "dry/configurable"
require "mail"
require "zeitwerk"

# Hanami
#
# @since 0.1.0
module Hanami
  # Hanami::Mailer
  class Mailer
    def self.gem_loader
      @gem_loader ||= Zeitwerk::Loader.new.tap do |loader|
        root = File.expand_path("..", __dir__)
        loader.tag = "hanami-mailer"
        loader.push_dir(root)
        loader.ignore(
          "#{root}/hanami-mailer.rb",
          "#{root}/hanami/mailer.rb",
          "#{root}/hanami/mailer/version.rb"
        )
      end
    end

    gem_loader.setup
  end
end
