# frozen_string_literal: true

require "dry/core/equalizer"

module Hanami
  class Mailer
    module DSL
      # An exposure defined on a mailer.
      #
      # @api private
      class Exposure
        include Dry::Equalizer(:name, :callable, :object, :options)

        attr_reader :name
        attr_reader :object
        attr_reader :options
        attr_reader :callable

        def initialize(name, proc = nil, object = nil, **options)
          @name = name
          @object = object
          @options = options
          @callable = PluckyProc.from_name(proc, name, object)
        end

        def bind(obj)
          self.class.new(name, callable&.proc, obj, **options)
        end

        def proc
          callable&.proc
        end

        def dependency_names
          return [] unless callable

          callable.dependency_names
        end

        def dependencies?
          !dependency_names.empty?
        end

        def private?
          options.fetch(:private, false)
        end

        def default_value
          options[:default]
        end

        def call(input, locals = {})
          if callable
            call_proc(input, locals)
          else
            input.fetch(name) { default_value }
          end
        end

        private

        def call_proc(input, locals)
          dependency_args = dependency_names.map { |name| locals.fetch(name) }
          callable.call(input, *dependency_args)
        end
      end
    end
  end
end
