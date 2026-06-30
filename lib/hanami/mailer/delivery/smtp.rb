# frozen_string_literal: true

require "net/smtp"

module Hanami
  class Mailer
    module Delivery
      # SMTP delivery method
      #
      # @api public
      # @since 3.0.0
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

          delivery_exception = nil
          begin
            mail.deliver!
          rescue Net::SMTPError => exception
            delivery_exception = exception
          end

          Result.new(
            message: message,
            response: mail,
            error: delivery_exception
          )
        end

        private

        # Convert a Hanami::Mailer::Message to a Mail::Message
        #
        # @param message [Message] the message to convert
        # @return [Mail::Message]
        def to_mail(message)
          require "mail"

          mail = build_mail(message)
          assign_body(mail, message)
          add_attachments(mail, message)

          mail
        end

        def build_mail(message)
          # Use local variables to avoid shadowing Mail DSL methods
          from_addr = message.from
          to_addr = message.to
          cc_addr = message.cc
          bcc_addr = message.bcc
          reply_to_addr = message.reply_to
          return_path_addr = message.return_path
          subject_text = message.subject
          charset_value = message.charset

          Mail.new do
            from from_addr
            to to_addr if to_addr
            cc cc_addr if cc_addr
            bcc bcc_addr if bcc_addr
            reply_to reply_to_addr if reply_to_addr
            return_path return_path_addr if return_path_addr
            subject subject_text
            self.charset = charset_value
            message.headers.each { |key, value| self[key] = value }
          end
        end

        def assign_body(mail, message)
          if message.html_body && message.text_body
            assign_alternative_body(mail, message)
          elsif message.attachments.any?
            assign_single_body_part(mail, message)
          else
            assign_single_body(mail, message)
          end
        end

        def assign_alternative_body(mail, message)
          # When attachments are present, the bodies must be wrapped in their own
          # multipart/alternative part so Mail produces the correct nested structure:
          # multipart/mixed > [multipart/alternative > [text, html], attachment].
          # Assigning html_part/text_part directly would leave a flat
          # multipart/alternative with the attachments as siblings of the bodies.
          if message.attachments.any?
            mail.add_part(alternative_body_part(message))
          else
            mail.text_part = body_part("text/plain", message.text_body, message.charset)
            mail.html_part = body_part("text/html", message.html_body, message.charset)
          end
        end

        def assign_single_body_part(mail, message)
          # A single body must be added as a part rather than via #content_type,
          # otherwise Mail pins the message as non-multipart and silently drops
          # the body once the attachment is added.
          mail.add_part(single_body_part(message))
        end

        def assign_single_body(mail, message)
          if message.html_body
            mail.content_type "text/html; charset=#{message.charset}"
            mail.body = message.html_body
          elsif message.text_body
            mail.content_type "text/plain; charset=#{message.charset}"
            mail.body = message.text_body
          end
        end

        def alternative_body_part(message)
          Mail::Part.new.tap do |part|
            part.content_type "multipart/alternative"
            part.text_part = body_part("text/plain", message.text_body, message.charset)
            part.html_part = body_part("text/html", message.html_body, message.charset)
          end
        end

        def single_body_part(message)
          if message.html_body
            body_part("text/html", message.html_body, message.charset)
          else
            body_part("text/plain", message.text_body, message.charset)
          end
        end

        def body_part(mime_type, content, charset)
          Mail::Part.new do
            content_type "#{mime_type}; charset=#{charset}"
            body content
          end
        end

        def add_attachments(mail, message)
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
        end
      end
    end
  end
end
