# frozen_string_literal: true

require_relative "clever_proc"

module Hanami
  class Mailer
    module DSL
      # Collection of attachments for a mailer
      #
      # @api private
      class Attachments
        # @api private
        attr_reader :definitions

        # @api private
        def initialize(definitions = [])
          @definitions = definitions
        end

        # @api private
        def add(name_or_filename, proc = nil, **options)
          definitions << Attachment.new(name_or_filename, proc, **options)
        end

        # @api private
        def import(definition)
          definitions << definition.dup
        end

        # @api private
        def each(&block)
          definitions.each(&block)
        end

        # @api private
        def bind(obj, input)
          definitions.flat_map { |definition|
            definition.bind(obj).call(input)
          }
        end

        # @api private
        def dup
          self.class.new(definitions.map(&:dup))
        end
      end

      # A single attachment declaration
      #
      # @api private
      class Attachment
        # @api private
        attr_reader :name_or_filename, :proc, :options

        # @api private
        def initialize(name_or_filename, proc = nil, **options)
          @name_or_filename = name_or_filename
          @proc = proc
          @options = options
        end

        # @api private
        def static_filename?
          name_or_filename.is_a?(String) && proc.nil?
        end

        # @api private
        def bind(obj)
          BoundAttachment.new(name_or_filename, proc, obj, **options)
        end

        # @api private
        def dup
          self.class.new(name_or_filename, proc, **options)
        end
      end

      # A bound attachment definition that can be evaluated
      #
      # @api private
      class BoundAttachment
        # @api private
        attr_reader :name_or_filename, :object, :options, :callable

        # @api private
        def initialize(name_or_filename, proc, object, **options)
          @name_or_filename = name_or_filename
          @object = object
          @options = options
          @callable = CleverProc.from_name(proc, name_or_filename, object)
        end

        # rubocop:disable Metrics/PerceivedComplexity

        # Evaluate the attachment definition and return an array of attachments
        #
        # @api private
        def call(input)
          if callable
            result = call_proc(input)
            # Array() converts a hash to key-value pairs, so we need to handle it specially
            results = result.is_a?(Array) ? result : [result]
            results.map { |attachment_data|
              process_attachment_data(attachment_data)
            }
          elsif name_or_filename.is_a?(String)
            # Static filename
            [{filename: name_or_filename, content: name_or_filename, inline: options[:inline] || false, static: true}]
          else
            # Method name
            result = object.public_send(name_or_filename)
            results = result.is_a?(Array) ? result : [result]
            results.map { |attachment_data|
              process_attachment_data(attachment_data)
            }
          end
        end
        # rubocop:enable Metrics/PerceivedComplexity

        private

        def call_proc(input)
          callable.call(input)
        end

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
