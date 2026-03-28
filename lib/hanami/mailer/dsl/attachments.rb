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

        # rubocop:disable Metrics/PerceivedComplexity

        # Evaluates the attachment definition and return an array of attachments.
        def call(input)
          if callable
            results = callable.call(input)
            results = [results] unless results.is_a?(Array)
            results.map { |attachment_data| process_attachment_data(attachment_data) }
          elsif name_or_filename.is_a?(String)
            # Static filename
            [{filename: name_or_filename, content: name_or_filename, inline: options[:inline] || false, static: true}]
          else
            # Method name
            results = object.public_send(name_or_filename)
            results = [results] unless results.is_a?(Array)
            results.map { |attachment_data| process_attachment_data(attachment_data) }
          end
        end
        # rubocop:enable Metrics/PerceivedComplexity

        private

        def process_attachment_data(data)
          unless data.is_a?(Hanami::Mailer::AttachmentData)
            raise ArgumentError, "Attachment blocks must return AttachmentData objects. Use the `file` helper method."
          end

          data.to_h
        end
      end
    end
  end
end
