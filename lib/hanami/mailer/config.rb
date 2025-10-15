# frozen_string_literal: true

require "dry/configurable"

module Hanami
  class Mailer
    # Mailer configuration
    #
    # @since 2.0.0
    class Config
      include Dry::Configurable

      DEFAULT_TEMPLATES_PATH = "."
      DEFAULT_CHARSET = "UTF-8"

      setting :templates_path, default: DEFAULT_TEMPLATES_PATH
      setting :charset, default: DEFAULT_CHARSET
      setting :delivery_method, default: :smtp
      setting :delivery_options, default: {}

      def initialize(**values)
        super()

        config.update(values.select { |k| _settings.key?(k) })

        yield(config) if block_given?
      end

      private

      def method_missing(name, ...)
        if config.respond_to?(name)
          config.public_send(name, ...)
        else
          super
        end
      end

      def respond_to_missing?(name, _incude_all = false)
        config.respond_to?(name) || super
      end
    end
  end
end
