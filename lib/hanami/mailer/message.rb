# frozen_string_literal: true

module Hanami
  class Mailer
    # Represents an email message
    #
    # @api private
    class Message
      # @api private
      attr_reader :from, :to, :cc, :bcc, :reply_to, :return_path, :subject

      # @api private
      attr_reader :html_body, :text_body, :attachments, :headers, :charset, :delivery_options

      # Initialize a new message
      #
      # @param from [String, Array<String>] sender address(es)
      # @param to [String, Array<String>, nil] recipient address(es)
      # @param cc [String, Array<String>, nil] carbon copy address(es)
      # @param bcc [String, Array<String>, nil] blind carbon copy address(es)
      # @param reply_to [String, Array<String>, nil] reply-to address(es)
      # @param return_path [String, Array<String>, nil] return path address(es) for bounces
      # @param subject [String] email subject
      # @param html_body [String, nil] HTML body content
      # @param text_body [String, nil] plain text body content
      # @param attachments [Array<Attachment>] array of attachments
      # @param headers [Hash] additional email headers
      # @param charset [String] character encoding (default: "UTF-8")
      # @param delivery_options [Hash] delivery-method-specific options
      #
      # @api private
      def initialize(from:, subject:, to: nil, cc: nil, bcc: nil, reply_to: nil, return_path: nil,
                     html_body: nil, text_body: nil, attachments: [], headers: {}, charset: "UTF-8",
                     delivery_options: {})
        @from = normalize_addresses(from)
        @to = normalize_addresses(to)
        @cc = normalize_addresses(cc)
        @bcc = normalize_addresses(bcc)
        @reply_to = normalize_addresses(reply_to)
        @return_path = normalize_addresses(return_path)
        @subject = subject
        @html_body = html_body
        @text_body = text_body
        @attachments = attachments
        @headers = headers
        @charset = charset
        @delivery_options = delivery_options

        validate_recipients!
      end

      # Convert message to hash representation
      #
      # @return [Hash]
      #
      # @api private
      def to_h
        {
          from: from,
          to: to,
          cc: cc,
          bcc: bcc,
          reply_to: reply_to,
          return_path: return_path,
          subject: subject,
          html_body: html_body,
          text_body: text_body,
          attachments: attachments,
          headers: headers,
          charset: charset,
          delivery_options: delivery_options
        }
      end

      private

      # Normalize addresses to array format
      def normalize_addresses(addresses)
        return nil if addresses.nil?
        return addresses if addresses.is_a?(Array)

        [addresses]
      end

      # Validate that at least one recipient is present
      def validate_recipients!
        if (to.nil? || to.empty?) && (cc.nil? || cc.empty?) && (bcc.nil? || bcc.empty?)
          raise MissingRecipientError
        end
      end
    end
  end
end
