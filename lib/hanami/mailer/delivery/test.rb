# frozen_string_literal: true

module Hanami
  class Mailer
    module Delivery
      # Test delivery method that stores messages in memory
      #
      # @api public
      class Test
        class << self
          # Returns all delivered messages
          #
          # @return [Array<Message>]
          #
          # @api public
          def deliveries
            @deliveries ||= []
          end

          # Clear all delivered messages
          #
          # @api public
          def clear
            @deliveries = []
          end
        end

        # Deliver a message by storing it in memory
        #
        # @param message [Message] the message to deliver
        # @return [Message] the delivered message
        #
        # @api private
        def call(message)
          self.class.deliveries << message
          message
        end
      end
    end
  end
end
