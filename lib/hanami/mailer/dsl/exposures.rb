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

        def call(input)
          # Avoid performance cost of tsorting when we don't need it
          names = dependencies? ? tsort : exposures.keys

          names
            .each_with_object({}) { |name, memo|
              next unless (exposure = self[name])

              value = exposure.(input, memo)
              value = yield(value, exposure) if block_given?

              memo[name] = value
            }
            .tap { |hsh|
              names.each do |key|
                hsh.delete(key) if self[key].private?
              end
            }
        end

        private

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
