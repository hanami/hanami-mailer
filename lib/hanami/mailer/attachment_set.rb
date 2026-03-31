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
        filenames = @attachments.map(&:filename)
        duplicates = filenames.select { |filename| filenames.count(filename) > 1 }.uniq
        raise DuplicateAttachmentError, duplicates.first if duplicates.any?
      end
    end
  end
end
