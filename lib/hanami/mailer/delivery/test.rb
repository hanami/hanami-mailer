# frozen_string_literal: true

module Hanami
  class Mailer
    module Delivery
      # Test delivery method that stores delivery results in memory
      #
      # @api public
      # @since 3.0.0
      class Test
        # Returns all delivery results
        #
        # @return [Array<Delivery::Result>]
        #
        # @api public
        # @since 3.0.0
        def deliveries
          @deliveries ||= []
        end

        # Clear all delivery results
        #
        # @api public
        # @since 3.0.0
        def clear
          deliveries.clear
        end

        # Deliver a message by storing a result in memory
        #
        # @param message [Message] the message to deliver
        # @return [Delivery::Result]
        #
        # @api private
        def call(message)
          result = Result.new(message: message)
          deliveries << result
          result
        end

        # Preview a message without delivering it.
        #
        # Returns the message unchanged. Delivery methods that support service-specific preview
        # logic (e.g. resolving a template from a remote API) can override this method.
        #
        # @param message [Message] the message to preview
        # @return [Message]
        #
        # @api public
        # @since 3.0.0
        def preview(message)
          message
        end
      end
    end
  end
end
