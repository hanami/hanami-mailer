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

    begin
      require "hanami/mailer/adapter_registry"
    rescue LoadError
      # hanami/mailer/adapter_registry not found
    end

    extend Dry::Configurable

    setting :formats, default: %i[html text]
    setting :adapters, default: {}

    DEFAULT_TEMPLATES_PATH = "."
    DEFAULT_CHARSET = "UTF-8"

    setting :templates_path, default: DEFAULT_TEMPLATES_PATH
    setting :charset, default: DEFAULT_CHARSET
    setting :delivery_method, default: :smtp
    setting :delivery_options, default: {}

    def self.inherited(subclass)
      super

      if subclass.superclass == Mailer
        subclass.class_eval do
          # TODO
          # include Validatable if defined?(Validatable)
        end
      end
    end

    def self.params(_klass = nil)
      message = %(To use `.params`, please add "hanami-validations" to your Gemfile)
      raise NoMethodError, message
    end

    private attr_reader :config
    # private attr_reader :view

    def initialize(config: self.class.config)
      @config = config
    end

    def deliver(...)
      binding.irb
      # delegate to the delivery method
      # delivery_klass.new(config: config).call(...)
    end

    private

    def build_delivery_adapter
      resolver = DeliveryMethodResolver.new(config)
      resolver.resolve
    end
  end
end
