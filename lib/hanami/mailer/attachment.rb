# frozen_string_literal: true

require "securerandom"

module Hanami
  class Mailer
    # Represents an email attachment
    #
    # @api private
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

      # @api private
      attr_reader :filename, :content, :content_type, :content_id

      # Initialize a new attachment
      #
      # @param filename [String] the filename for the attachment
      # @param content [String, IO] the attachment content or file path
      # @param content_type [String, nil] optional MIME type
      # @param inline [Boolean] whether this is an inline attachment
      #
      # @api private
      def initialize(filename:, content:, content_type: nil, inline: false)
        @filename = filename
        @content = content
        @content_type = content_type || detect_content_type(filename)
        @inline = inline
        @content_id = inline ? generate_content_id(filename) : nil
      end

      # Check if this is an inline attachment
      #
      # @return [Boolean]
      #
      # @api private
      def inline?
        @inline
      end

      private

      # Detect content type from filename extension
      def detect_content_type(filename)
        ext = File.extname(filename).downcase
        MIME_TYPES[ext] || "application/octet-stream"
      end

      # Generate a content ID for inline attachments based on filename
      # This allows templates to reference inline images using cid:filename
      def generate_content_id(filename)
        filename
      end
    end
  end
end
