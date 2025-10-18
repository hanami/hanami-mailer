# frozen_string_literal: true

require "dry/configurable"

module Hanami
  class Mailer
    # Mailer configuration
    #
    # @since 2.0.0
    class Config
      include Dry::Configurable

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
