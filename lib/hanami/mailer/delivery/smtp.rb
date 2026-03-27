# frozen_string_literal: true

require "net/smtp"

module Hanami
  class Mailer
    module Delivery
      # SMTP delivery method
      #
      # @api public
      class SMTP
        # Initialize SMTP delivery with configuration
        #
        # @param options [Hash] SMTP configuration options
        #
        # @api private
        def initialize(**options)
          @options = options
        end

        # Deliver a message via SMTP
        #
        # @param message [Message] the message to deliver
        #
        # @api private
        def call(message)
          mail = to_mail(message)
          mail.delivery_method(:smtp, @options)

          exception = nil
          begin
            mail.deliver!
          rescue Net::SMTPError => exception
            exception = exception
          end

          Result.new(
            message: message,
            response: mail,
            success: exception.nil?,
            error: exception
          )
        end

        private

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        # Convert a Hanami::Mailer::Message to a Mail::Message
        #
        # @param message [Message] the message to convert
        # @return [Mail::Message]
        def to_mail(message)
          require "mail"

          # Use local variables to avoid shadowing Mail DSL methods
          from_addr = message.from
          to_addr = message.to
          cc_addr = message.cc
          bcc_addr = message.bcc
          reply_to_addr = message.reply_to
          return_path_addr = message.return_path
          subject_text = message.subject
          charset_value = message.charset

          mail = Mail.new do
            from from_addr
            to to_addr if to_addr
            cc cc_addr if cc_addr
            bcc bcc_addr if bcc_addr
            reply_to reply_to_addr if reply_to_addr
            subject subject_text
          end

          # Set return_path separately as it's not part of the Mail DSL block
          mail.return_path = return_path_addr if return_path_addr

          mail.charset = charset_value

          # Add custom headers
          message.headers.each do |key, value|
            mail[key] = value
          end

          # Set body content
          if message.html_body && message.text_body
            mail.html_part = Mail::Part.new do
              content_type "text/html; charset=#{charset_value}"
              body message.html_body
            end

            mail.text_part = Mail::Part.new do
              content_type "text/plain; charset=#{charset_value}"
              body message.text_body
            end
          elsif message.html_body
            mail.content_type "text/html; charset=#{charset_value}"
            mail.body = message.html_body
          elsif message.text_body
            mail.content_type "text/plain; charset=#{charset_value}"
            mail.body = message.text_body
          end

          # Add attachments
          message.attachments.each do |attachment|
            if attachment.inline?
              mail.attachments.inline[attachment.filename] = {
                content: attachment.content,
                content_type: attachment.content_type,
                content_id: "<#{attachment.content_id}>"
              }
            else
              mail.attachments[attachment.filename] = {
                content: attachment.content,
                content_type: attachment.content_type
              }
            end
          end

          mail
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      end
    end
  end
end
