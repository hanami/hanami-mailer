module Hanami
  class Mailer
    class DeliveryMethodResolver
      def initialize(config)
        @config = config
      end

      def resolve
        delivery_method = @config.delivery_method
        AdapterRegistry.resolve(delivery_method, @config)
      end

      private

      attr_reader :config
    end
  end
end
