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

        # @api private
        attr_reader :exposures

        # @api private
        def initialize(exposures = {})
          @exposures = exposures
        end

        # @api private
        def initialize_copy(source)
          super
          @exposures = source.exposures.transform_values(&:dup)
        end

        # @api private
        def key?(name)
          exposures.key?(name)
        end

        # @api private
        def [](name)
          exposures[name]
        end

        # @api private
        def each(&block)
          exposures.each(&block)
        end

        # @api private
        def empty?
          exposures.empty?
        end

        # @api private
        def add(name, proc = nil, **options)
          exposures[name] = Exposure.new(name, proc, **options)
        end

        # @api private
        def import(name, exposure)
          exposures[name] = exposure.dup
        end

        # @api private
        def bind(obj)
          bound_exposures = exposures.transform_values { |exposure|
            exposure.bind(obj)
          }

          self.class.new(bound_exposures)
        end

        # rubocop:disable Metrics/PerceivedComplexity

        # @api private
        def call(input)
          # Avoid performance cost of tsorting when we don't need it
          names =
            if exposures.values.any?(&:dependencies?) # TODO: this sholud be cachable at time of `#add`
              tsort
            else
              exposures.keys
            end

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
        # rubocop:enable Metrics/PerceivedComplexity

        private

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
