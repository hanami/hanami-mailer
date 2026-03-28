# frozen_string_literal: true

module Hanami
  class Mailer
    module DSL
      # Collection of attachments for a mailer.
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

        def bind(obj, input)
          definitions.flat_map { |definition|
            definition.bind(obj).call(input)
          }
        end

        def dup
          self.class.new(definitions.map(&:dup))
        end
      end

      # A single attachment declaration.
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

      # A bound attachment definition that can be evaluated
      #
      # @api private
      class BoundAttachment
        attr_reader :name_or_filename, :object, :options, :callable

        def initialize(name_or_filename, proc, object, **options)
          @name_or_filename = name_or_filename
          @object = object
          @options = options
          @callable = PluckyProc.from_name(proc, name_or_filename, object)
        end

        # Evaluates the attachment definition and return an array of attachments.
        def call(input)
          if callable
            results = Array(callable.call(input))
            results.map { |attachment_data| attachment_hash(attachment_data) }
          else
            # Static filename string with no proc or matching method
            [
              {
                filename: name_or_filename,
                content: name_or_filename,
                inline: options[:inline],
                static: true
              }
            ]
          end
        end

        private

        def attachment_hash(data)
          unless data.is_a?(AttachmentData)
            raise ArgumentError, "Attachment blocks must return AttachmentData objects. Use the `file` helper method."
          end

          data.to_h
        end
      end
    end
  end
end
