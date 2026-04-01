# frozen_string_literal: true

module Hanami
  class Mailer
    # A collection of attachments that enforces uniqueness.
    #
    # Aids the preparation of a single email delivery. It is returned from {DSL::Attachments#bind},
    # containing class-level attachment definitions. Runtime attachments can be added via {#concat},
    # and the finalized array is obtained via {#to_a}, which raises if any filenames are duplicated.
    #
    # @api private
    class AttachmentSet
      def initialize(attachments = [])
        @attachments = attachments
      end

      def concat(runtime_attachments)
        Array(runtime_attachments).each do |attachment|
          @attachments << Attachment.from(attachment)
        end

        self
      end

      def to_a
        ensure_unique!
        @attachments.dup
      end

      private

      def ensure_unique!
        duplicate = @attachments.map(&:filename).tally.find { |_, count| count > 1 }&.first
        raise DuplicateAttachmentError, duplicate if duplicate
      end
    end
  end
end
