# frozen_string_literal: true

module Hanami
  class Mailer
    class DeliveryAdapter
      def initialize(config)
        @config = config
        validate_configuration!
      end

      def deliver!(mail)
        raise NotImplementedError, "Subclasses must implement #deliver!"
      end

      private

      attr_reader :config

      def validate_configuration!
        # Override in subclasses for specific validation
      end
    end
  end
end
