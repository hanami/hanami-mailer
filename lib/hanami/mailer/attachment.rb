# frozen_string_literal: true

module Hanami
  class Mailer
    # Represents an email attachment
    #
    # @api public
    class Attachment
      # Common MIME types for attachments
      #
      # @api private
      MIME_TYPES = {
        ".pdf" => "application/pdf",
        ".zip" => "application/zip",
        ".jpg" => "image/jpeg",
        ".jpeg" => "image/jpeg",
        ".png" => "image/png",
        ".gif" => "image/gif",
        ".txt" => "text/plain",
        ".csv" => "text/csv",
        ".doc" => "application/msword",
        ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ".xls" => "application/vnd.ms-excel",
        ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      }.freeze

      class << self
        # Coerces runtime attachment input into an Attachment
        #
        # @param input [Attachment, Hash] attachment or hash with attachment attributes
        #
        # @return [Attachment]
        #
        # @raise [ArgumentError] if input cannot be coerced
        #
        # @api private
        def from(input)
          case input
          when Attachment
            input
          when Hash
            # Extract keys explicitly rather than splatting so that missing keys arrive as nil,
            # letting the argument checks in #initialize raise clearer errors.
            new(
              filename: input[:filename],
              content: input[:content],
              content_type: input[:content_type],
              inline: input[:inline]
            )
          else
            raise ArgumentError, "Cannot convert #{input.class} to Attachment"
          end
        end

        # Resolve a static filename from attachment paths and return an Attachment
        #
        # @param filename [String] the filename to resolve
        # @param attachment_paths [Array<String>] paths to search for the file
        # @param inline [Boolean] whether this is an inline attachment
        #
        # @return [Attachment]
        #
        # @raise [MissingAttachmentError] if the file cannot be found
        #
        # @api private
        def from_file(filename, attachment_paths:, inline: false)
          content = read_attachment_file(filename, attachment_paths)

          new(filename:, content:, inline:)
        end

        private

        def read_attachment_file(filename, attachment_paths)
          if attachment_paths.any?
            attachment_paths.each do |path|
              full_path = File.join(path, filename)
              return File.read(full_path) if File.exist?(full_path)
            end
            raise MissingAttachmentError.new(filename, attachment_paths)
          elsif File.exist?(filename)
            File.read(filename)
          else
            raise MissingAttachmentError.new(filename, [])
          end
        end
      end

      # @api private
      attr_reader :filename, :content, :content_type, :content_id

      # Initialize a new attachment
      #
      # @param filename [String] the filename for the attachment
      # @param content [String, IO] the attachment content
      # @param content_type [String, nil] optional MIME type
      # @param inline [Boolean] whether this is an inline attachment
      #
      # @raise [ArgumentError] if filename or content is missing
      #
      # @api public
      def initialize(filename:, content:, content_type: nil, inline: false)
        raise ArgumentError, "filename is required" if filename.nil? || (filename.is_a?(String) && filename.empty?)
        raise ArgumentError, "content is required" if content.nil?

        @filename = filename
        @content = content
        @content_type = content_type || detect_content_type(filename)
        @inline = inline
        @content_id = inline ? filename : nil
      end

      # Returns true if this is an inline attachment.
      #
      # @return [Boolean]
      #
      # @api public
      def inline? = @inline

      private

      def detect_content_type(filename)
        ext = File.extname(filename).downcase
        MIME_TYPES[ext] || "application/octet-stream"
      end
    end
  end
end
