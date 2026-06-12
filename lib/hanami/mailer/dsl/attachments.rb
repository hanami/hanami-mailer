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

        private def initialize_copy(source)
          super
          @definitions = source.definitions.map(&:dup)
        end

        def add(name_or_filename, proc = nil, **options)
          definitions << Attachment.new(name_or_filename, proc, **options)
        end

        # Returns a copy with every definition bound to the mailer instance.
        def bind(obj)
          self.class.new(definitions.map { |definition| definition.bind(obj) })
        end

        # Evaluates the bound definitions, returning an {AttachmentSet} of {Attachment} instances.
        #
        # Each definition's positional parameters resolve against `dependencies` (the mailer's
        # exposure values); its keyword parameters resolve against `input` (the raw `deliver` input).
        def call(input, dependencies: {})
          attachments = definitions.flat_map { |definition| definition.call(input, dependencies) }

          AttachmentSet.new(attachments)
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

        private def initialize_copy(source)
          super
          @options = source.options.dup
        end

        def bind(obj)
          BoundAttachment.new(name_or_filename, proc, obj, **options)
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
        #
        # Positional parameters resolve against `dependencies` (the mailer's exposure values);
        # keyword parameters resolve against `input`.
        def call(input, dependencies = {})
          Array(@callable.call(input, *dependency_args(dependencies))).each { ensure_attachment(_1) }
        end

        private

        def dependency_args(dependencies)
          return [] unless @callable.respond_to?(:dependency_names)

          @callable.dependency_names.map { |name| dependencies.fetch(name) }
        end

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
