# frozen_string_literal: true

module Hanami
  class Mailer
    # Integration module for Hanami::View support.
    # This module is included when Hanami::View is available,
    # providing automatic view building and settings inheritance.
    #
    # @api private
    module ViewIntegration
      # @api private
      def self.included(base)
        base.class_eval do
          # Prepend the initializer module to wrap initialization
          prepend Initializer

          # Base path for template inference
          # e.g., "mailers" will strip "mailers/" from "Mailers::WelcomeMailer" -> "welcome_mailer"
          setting :template_inference_base, default: nil

          # Copy all settings from Hanami::View to support default view integration.
          # This allows mailers to configure view-related settings (like layouts_dir,
          # default_format, inflector, etc.) without having to manually redefine them.
          existing_settings = config._settings.keys.to_set
          Hanami::View.config._settings.each do |setting_def|
            next if existing_settings.include?(setting_def.name)

            setting(
              setting_def.name,
              default: setting_def.default,
              constructor: setting_def.constructor,
              **setting_def.options
            )
          end
        end
      end

      # Internal module for prepending initialize behavior.
      # Wraps the base class initialize to provide automatic view building.
      #
      # @api private
      module Initializer
        # @api private
        def initialize(view: DefaultViewBuilder.call(self), **)
          super
        end
      end

      # Builder class for constructing default views.
      # Keeps view building logic separate from mailer instances.
      #
      # @api private
      class DefaultViewBuilder
        class << self
          # Build a default view from exposures if Hanami::View is available
          #
          # @param mailer [Hanami::Mailer] the mailer instance
          # @return [Hanami::View, nil]
          # @api private
          def call(mailer)
            return nil if mailer.class.exposures.empty? && mailer.class.config.paths.empty?

            build_view_class(
              paths: mailer.class.config.paths,
              template: inferred_template(mailer),
              exposures: mailer.class.exposures,
              config: mailer.class.config
            )
          end

          private

          # Infer template path from class name
          #
          # @param mailer [Hanami::Mailer] the mailer instance
          # @return [String, nil]
          # @api private
          #
          # @example
          #   Mailers::WelcomeMailer -> "mailers/welcome_mailer"
          def inferred_template(mailer)
            return nil unless mailer.class.name

            base = mailer.class.config.template_inference_base
            name = mailer.class.name.gsub("::", "/").downcase
            name = name.delete_prefix("#{base}/") if base
            name
          end

          # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity

          # Build a Hanami::View instance from mailer configuration
          #
          # @param paths [Array<String>] template paths
          # @param template [String, nil] template name
          # @param exposures [DSL::Exposures] exposure definitions
          # @param config [Dry::Configurable::Config] mailer configuration
          # @return [Hanami::View, nil]
          # @api private
          def build_view_class(paths:, template:, exposures:, config:)
            return nil unless defined?(Hanami::View)

            view_paths = paths
            view_template = template
            view_exposures = exposures
            mailer_config = config

            Class.new(Hanami::View) do
              # Copy all relevant settings from mailer config to view config
              Hanami::View.config._settings.each do |setting_def|
                setting_name = setting_def.name

                # Skip mailer-specific settings
                next if %i[default_from default_charset template_inference_base].include?(setting_name)

                # Apply the setting value from mailer config if it exists
                if mailer_config.respond_to?(setting_name)
                  config.public_send(:"#{setting_name}=", mailer_config.public_send(setting_name))
                end
              end

              # Override specific settings for mailer use
              config.paths = view_paths if view_paths && !view_paths.empty?
              config.template = view_template if view_template
              config.layout = false

              view_exposures.each do |name, exposure|
                if exposure.proc
                  expose(name, **exposure.options, &exposure.proc)
                else
                  expose(name, **exposure.options)
                end
              end
            end.new
          end
          # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity
        end
      end
    end
  end
end
