# frozen_string_literal: true

require "tsort"
require "dry/core/equalizer"

module Hanami
  class Mailer
    module DSL
      # @api private
      class Exposures
        include Dry::Equalizer(:exposures)
        include TSort

        attr_reader :exposures

        def initialize(exposures = {})
          @exposures = exposures
          @has_dependencies = false
        end

        def initialize_copy(source)
          super
          @exposures = source.exposures.transform_values(&:dup)
          @has_dependencies = source.instance_variable_get(:@has_dependencies)
        end

        def key?(name)
          exposures.key?(name)
        end

        def [](name)
          exposures[name]
        end

        def each(&block)
          exposures.each(&block)
        end

        def empty?
          exposures.empty?
        end

        def add(name, proc = nil, **options)
          exposure = Exposure.new(name, proc, **options)
          @has_dependencies ||= exposure.dependencies?
          exposures[name] = exposure
        end

        def import(name, exposure)
          exposures[name] = exposure.dup
        end

        def bind(obj)
          bound_exposures = exposures.transform_values { |exposure|
            exposure.bind(obj)
          }

          copy = self.class.new(bound_exposures)
          copy.instance_variable_set(:@has_dependencies, @has_dependencies)
          copy
        end

        # Evaluates each exposure and returns a hash of their values.
        #
        # By default each exposure's positional parameters resolve against its sibling exposures in
        # this collection (the values accumulate as the collection is evaluated, ordered by tsort).
        #
        # When `dependencies` is given, positional parameters resolve against those instead, and no
        # sibling resolution (or tsort) takes place. This is how the mailer collections like headers
        # and delivery options consume the mailer's exposures as their one shared dependency graph.
        def call(input, dependencies: nil)
          ordered_evaluation_keys(dependencies).each_with_object({}) { |name, memo|
            next unless (exposure = self[name])

            value = exposure.(input, dependencies || memo)
            value = yield(value, exposure) if block_given?

            memo[name] = value
          }
        end

        # Removes private exposures from a hash of evaluated values.
        #
        # Private exposures are computed and stay available as positional dependencies — to other
        # exposures, and to the mailer's headers, attachments, and delivery options — but they are
        # never passed to the view for rendering. This filters them out for that final step.
        def reject_private(values)
          values.reject { |name, _| self[name]&.private? }
        end

        private

        # With external dependencies, there are no sibling dependencies to order, so tsort is only
        # needed when resolving siblings within our own collection.
        def ordered_evaluation_keys(dependencies)
          dependencies.nil? && dependencies? ? tsort : exposures.keys
        end

        def dependencies? = @has_dependencies

        def tsort_each_node(&block)
          exposures.each_key(&block)
        end

        def tsort_each_child(name, &block)
          self[name].dependency_names.each(&block) if exposures.key?(name)
        end
      end
    end
  end
end
