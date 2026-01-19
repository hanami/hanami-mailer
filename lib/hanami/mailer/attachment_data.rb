# frozen_string_literal: true

module Hanami
  class Mailer
    # Represents attachment data for building email attachments
    #
    # This class provides a structured way to define attachment data,
    # replacing raw hashes with a proper object that validates required fields.
    #
    # @api public
    class AttachmentData
      # @api public
      attr_reader :filename, :content, :content_type, :inline

      # Initialize a new attachment data object
      #
      # @param filename [String] the filename for the attachment
      # @param content [String] the attachment content
      # @param content_type [String, nil] optional MIME type
      # @param inline [Boolean] whether this is an inline attachment
      #
      # @raise [ArgumentError] if filename or content is missing
      #
      # @api public
      def initialize(filename:, content:, content_type: nil, inline: false)
        raise ArgumentError, "filename is required" if filename.nil? || filename.empty?
        raise ArgumentError, "content is required" if content.nil?

        @filename = filename
        @content = content
        @content_type = content_type
        @inline = inline
      end

      # Convert to hash representation
      #
      # @return [Hash]
      #
      # @api private
      def to_h
        {
          filename: filename,
          content: content,
          content_type: content_type,
          inline: inline
        }
      end

      # Check if this is an inline attachment
      #
      # @return [Boolean]
      #
      # @api public
      def inline?
        @inline
      end
    end
  end
end
