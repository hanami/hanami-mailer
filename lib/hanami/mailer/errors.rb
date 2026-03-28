# frozen_string_literal: true

module Hanami
  class Mailer
    # Base error class for all Hanami::Mailer errors
    #
    # @api public
    class Error < StandardError
    end

    # Raised when a mailer is missing required delivery configuration
    #
    # @api public
    class MissingDeliveryError < Error
      def initialize(message = "Missing delivery method. Configure a delivery method using `config.delivery = ...`")
        super
      end
    end

    # Raised when a mailer message is missing required recipient information
    #
    # @api public
    class MissingRecipientError < Error
      def initialize(message = "Missing recipient. Provide at least one of: to, cc, or bcc")
        super
      end
    end

    # Raised when a static attachment file cannot be found
    #
    # @api public
    class MissingAttachmentError < Error
      def initialize(filename, paths = [])
        message =
          if paths.any?
            "Attachment file not found: #{filename}. "\
            "Searched in: #{paths.join(', ')}"
          else
            "Attachment file not found: #{filename}. " \
            "Configure `attachment_paths` to specify where attachment files are located."
          end
        super(message)
      end
    end

    # Raised when duplicate attachment filenames are detected
    #
    # @api public
    class DuplicateAttachmentError < Error
      def initialize(filename)
        super(
          "Duplicate attachment filename: #{filename.inspect}. " \
          "Each attachment must have a unique filename."
        )
      end
    end
  end
end
