# frozen_string_literal: true

module Hanami
  class Mailer
    module DSL
      # Collection of class-level attachment definitions for a mailer.
      #
      # @api private
      class Attachments
        attr_reader :definitions

        def initialize(definitions = [])
          @definitions = definitions
        end

        def add(name_or_filename, proc = nil, **options)
          definitions << Attachment.new(name_or_filename, proc, **options)
        end

        def import(definition)
          definitions << definition.dup
        end

        def each(&block)
          definitions.each(&block)
        end

        # Binds all definitions to a mailer instance and evaluates them, returning an
        # {AttachmentSet} of {Attachment} instances.
        def bind(obj, input)
          attachments = definitions.flat_map { |definition| definition.bind(obj).call(input) }

          AttachmentSet.new(attachments)
        end

        def dup
          self.class.new(definitions.map(&:dup))
        end
      end

      # A class-level attachment definition.
      #
      # @api private
      class Attachment
        attr_reader :name_or_filename, :proc, :options

        def initialize(name_or_filename, proc = nil, **options)
          @name_or_filename = name_or_filename
          @proc = proc
          @options = options
        end

        def static_filename?
          name_or_filename.is_a?(String) && proc.nil?
        end

        def bind(obj)
          BoundAttachment.new(name_or_filename, proc, obj, **options)
        end

        def dup
          self.class.new(name_or_filename, proc, **options)
        end
      end

      # A bound attachment definition that can be evaluated in the context of a mailer instance.
      #
      # @api private
      class BoundAttachment
        def initialize(name_or_filename, proc, object, **options)
          @name_or_filename = name_or_filename
          @object = object
          @options = options
          @callable = PluckyProc.from_name(proc, name_or_filename, object) || static_callable
        end

        # Evaluates the attachment definition and returns an array of Attachment objects.
        def call(input)
          Array(@callable.call(input)).each { ensure_attachment(_1) }
        end

        private

        def static_callable
          filename = @name_or_filename
          attachment_paths = @object.class.config.attachment_paths
          inline = @options[:inline]

          ->(*) { Mailer::Attachment.from_file(filename, attachment_paths:, inline:) }
        end

        def ensure_attachment(value)
          unless value.is_a?(Mailer::Attachment)
            raise ArgumentError, <<~MSG
              Attachment blocks must return Attachment objects. Use the `file` helper method.
            MSG
          end
        end
      end
    end
  end
end
