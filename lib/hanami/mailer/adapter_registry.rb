# frozen_string_literal: true

module Hanami
  class Mailer
    class AdapterRegistry
      class ConfigurationError < StandardError; end

      @adapters = {}

      def self.register(name, adapter_class)
        @adapters[name.to_sym] = adapter_class
      end

      def self.resolve(delivery_method, config)
        adapter_class = find_adapter(delivery_method)
        adapter_class.new(config)
      end

      def self.find_adapter(method)
        case method
        when Symbol, String
          registered_adapter(method) || discover_adapter(method)
        when Class
          method
        else
          raise ConfigurationError, "Invalid delivery method: #{method}"
        end
      end

      def self.registered_adapter(name)
        @adapters[name.to_sym]
      end

      def self.discover_adapter(name)
        adapter_name = "#{name.to_s.split('_').map(&:capitalize).join}Adapter"
        const_name = "Hanami::Mailer::Adapters::#{adapter_name}"

        if Object.const_defined?(const_name)
          Object.const_get(const_name)
        else
          raise ConfigurationError, "Adapter not found: #{const_name}"
        end
      end
    end
  end
end
