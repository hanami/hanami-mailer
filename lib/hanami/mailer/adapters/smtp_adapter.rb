module Hanami
  class Mailer
    module Adapters
      class SmtpAdapter < DeliveryAdapter
        def deliver!(mail)
          binding.irb
          mail.delivery_method(:smtp, smtp_settings)
          mail.deliver!
        end

        private

        def smtp_settings
          config.delivery_options.merge(
            address: config.delivery_options[:address] || "localhost",
            port: config.delivery_options[:port] || 25
          )
        end

        def validate_configuration!
          unless config.delivery_options[:address]
            raise ConfigurationError, "SMTP address is required"
          end
        end
      end
    end
  end
end
