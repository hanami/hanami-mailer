# frozen_string_literal: true

module Hanami
  class Mailer
    module DSL
      # A plucky proc that evaluates with automatic keyword argument extraction from input.
      #
      # This class encapsulates the logic for calling procs/methods in a mailer context,
      # handling both positional and keyword arguments intelligently based on the proc's
      # signature.
      #
      # @api private
      class PluckyProc
        attr_reader :proc, :context

        # Create a new plucky proc
        #
        # @param proc [Proc, Method, nil] the proc or method to evaluate
        # @param context [Object] the object context for instance_exec
        def initialize(proc, context:)
          @proc = proc
          @context = context
        end

        # Create a PluckyProc from either a proc or a method name on the context
        #
        # @param proc [Proc, Method, nil] the proc to use, or nil to look up a method
        # @param name [Symbol] the method name to look up if proc is nil
        # @param context [Object] the context object
        #
        # @return [PluckyProc, nil] a new PluckyProc or nil if no proc/method found
        def self.from_name(proc, name, context)
          resolved_proc =
            if proc
              proc
            elsif context.respond_to?(name, _include_private = true)
              context.method(name)
            end

          new(resolved_proc, context: context) if resolved_proc
        end

        # Evaluate the proc with input and optional positional arguments
        #
        # @param input [Hash] input hash to extract keyword arguments from
        # @param args [Array] positional arguments to pass to the proc
        #
        # @return [Object] the result of evaluating the proc
        def call(input, *args)
          return nil unless proc

          keywords = extract_keywords(input)

          if keywords.empty?
            call_without_keywords(*args)
          else
            call_with_keywords(keywords, *args)
          end
        end

        # Check if this evaluator has a proc to call
        #
        # @return [Boolean]
        def callable?
          !proc.nil?
        end

        # Get dependency parameter names (positional args: :req, :opt)
        #
        # @return [Array<Symbol>] parameter names
        def dependency_names
          @dependency_names ||=
            if proc
              proc.parameters.each_with_object([]) { |(type, name), names|
                names << name if %i[req opt].include?(type)
              }
            else
              []
            end
        end

        # Get keyword parameter names (:key, :keyreq)
        #
        # @return [Array<Symbol>] parameter names
        def keyword_names
          @keyword_names ||=
            if proc
              proc.parameters.each_with_object([]) { |(type, name), keys|
                keys << name if %i[key keyreq].include?(type)
              }
            else
              []
            end
        end

        private

        def call_without_keywords(*args)
          if proc.is_a?(Method)
            proc.call(*args)
          else
            context.instance_exec(*args, &proc)
          end
        end

        def call_with_keywords(keywords, *args)
          if proc.is_a?(Method)
            proc.call(*args, **keywords)
          else
            context.instance_exec(*args, **keywords, &proc)
          end
        end

        def extract_keywords(input)
          keywords = {}
          params = proc.parameters

          # Extract specific keyword parameters (:key, :keyreq)
          params.each do |type, name|
            if %i[key keyreq].include?(type) && input.key?(name)
              keywords[name] = input[name]
            end
          end

          # Merge all input for **kwargs (:keyrest)
          if params.any? { |(type, _)| type == :keyrest }
            keywords.merge!(input)
          end

          keywords
        end
      end
    end
  end
end
