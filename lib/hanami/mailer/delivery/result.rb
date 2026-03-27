# frozen_string_literal: true

module Hanami
  class Mailer
    module Delivery
      # Represents the outcome of a message delivery attempt.
      #
      # This is the base class for delivery results. Delivery methods return an instance of this
      # class (or a subclass) from their #call method. Third-party delivery methods are encouraged
      # to subclass this and add any service-specific attributes they need.
      #
      # @example Checking a result
      #   result = mailer.deliver(user: user)
      #   if result.success?
      #     log.info "Delivered to #{result.message.to.join(', ')}"
      #   else
      #     log.error "Delivery failed: #{result.error.message}"
      #   end
      #
      # @example A third-party delivery method returning a richer result
      #   class Delivery::Postmark::Result < Hanami::Mailer::Delivery::Result
      #     attr_reader :message_id, :submitted_at
      #
      #     def initialize(message_id:, submitted_at: nil, **)
      #       super(**)
      #       @message_id   = message_id
      #       @submitted_at = submitted_at
      #     end
      #   end
      #
      # @api public
      class Result
        # The prepared message that was (or was attempted to be) delivered.
        #
        # @return [Hanami::Mailer::Message]
        #
        # @api public
        attr_reader :message

        # The raw return value from the delivery method, if any.
        #
        # For SMTP delivery this will be the Mail::Message object. For test delivery this will be
        # nil. The exact type is delivery-method-specific; consult the documentation for the
        # delivery method you are using.
        #
        # @return [Object, nil]
        #
        # @api public
        attr_reader :response

        # The exception raised during delivery, if delivery failed.
        #
        # @return [Exception, nil]
        #
        # @api public
        attr_reader :error

        # @param message [Hanami::Mailer::Message] the prepared message
        # @param response [Object, nil] the raw response from the delivery method
        # @param success [Boolean] whether delivery succeeded (default: true)
        # @param error [Exception, nil] the exception raised, if delivery failed
        #
        # @api private
        def initialize(message:, response: nil, success: true, error: nil)
          @message  = message
          @response = response
          @success  = success
          @error    = error
        end

        # Returns true if delivery succeeded.
        #
        # @return [Boolean]
        #
        # @api public
        def success?
          @success
        end
      end
    end
  end
end
