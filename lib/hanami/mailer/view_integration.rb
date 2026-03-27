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

            configured_template = mailer.class.config.template
            template = configured_template && !configured_template.empty? ? configured_template : inferred_template(mailer)

            build_view_class(
              paths: mailer.class.config.paths,
              template: template,
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

            mailer.class.config.template_inference_base
            mailer.class.name
              .gsub("::", "/")
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .downcase

            # Keep the full path including the base - template_inference_base is just metadata
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

            # paths is required by Hanami::View - return nil if not configured
            return nil if view_paths.nil? || view_paths.empty?

            view_class = Class.new(Hanami::View) do
              # Set critical required settings first
              self.config.paths = view_paths
              self.config.template = view_template
              self.config.layout = false

              # Copy remaining settings from mailer config to view config
              Hanami::View.config._settings.each do |setting_def|
                setting_name = setting_def.name

                # Skip mailer-specific settings and already-set critical settings
                #
                # FIXME: need a nicer way of doing this
                next if %i[default_from default_charset template_inference_base paths template
                           layout].include?(setting_name)

                # Apply the setting value from mailer config if it exists
                if mailer_config.respond_to?(setting_name)
                  self.config.public_send(:"#{setting_name}=", mailer_config.public_send(setting_name))
                end
              end

              view_exposures.each do |name, exposure|
                if exposure.proc
                  expose(name, **exposure.options, &exposure.proc)
                else
                  expose(name, **exposure.options)
                end
              end
            end

            view_class.new
          end
          # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity
        end
      end
    end
  end
end
