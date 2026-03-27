# frozen_string_literal: true

require "dry/core/equalizer"
require_relative "clever_proc"

module Hanami
  class Mailer
    module DSL
      # An exposure defined on a mailer
      #
      # @api private
      class Exposure
        include Dry::Equalizer(:name, :callable, :object, :options)

        # @api private
        attr_reader :name

        # @api private
        attr_reader :object

        # @api private
        attr_reader :options

        # @api private
        attr_reader :callable

        # @api private
        def initialize(name, proc = nil, object = nil, **options)
          @name = name
          @object = object
          @options = options
          @callable = CleverProc.from_name(proc, name, object)
        end

        # @api private
        def bind(obj)
          self.class.new(name, callable&.proc, obj, **options)
        end

        # @api private
        def proc
          callable&.proc
        end

        # @api private
        def dependency_names
          return [] unless callable

          callable.dependency_names
        end

        # @api private
        def dependencies?
          !dependency_names.empty?
        end

        # @api private
        def input_keys
          return [] unless callable

          callable.keyword_names
        end

        # @api private
        def for_layout?
          options.fetch(:layout, false)
        end

        # @api private
        def decorate?
          options.fetch(:decorate, true)
        end

        # @api private
        def private?
          options.fetch(:private, false)
        end

        # @api private
        def default_value
          options[:default]
        end

        # @api private
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
