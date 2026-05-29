# frozen_string_literal: true

module Hanami
  class Mailer
    # Integration module for Hanami::View support.
    # This module is included when Hanami::View is available,
    # providing automatic view building and settings inheritance.
    #
    # @api private
    module ViewIntegration
      def self.included(base)
        base.class_eval do
          # Prepend the initializer module to wrap initialization
          prepend PrependedMethods

          # Whether to automatically build views from exposures
          # Set to false to disable automatic view integration behavior
          setting :integrate_view, default: true

          # The base class used when building the mailer's view. Defaults to Hanami::View, but
          # may be set to an already-configured view class (such as a view class within a Hanami
          # app), in which case the built view inherits that class's configuration — context,
          # parts, scopes, paths, helpers and so on.
          setting :view_class, default: Hanami::View

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

      # Internal module for prepending initialize and render behavior.
      # Wraps the base class to provide automatic view building and
      # per-format template error handling.
      #
      # @api private
      module PrependedMethods
        def initialize(view: nil, **)
          view ||= DefaultViewBuilder.call(self) if self.class.config.integrate_view
          super
        end

        # Renders HTML and text bodies, handling missing templates per format.
        def render(input, format: nil)
          html, html_error = try_render(:html, input) unless format == :text
          text, text_error = try_render(:text, input) unless format == :html

          # Tolerate one missing template if attempting to render both. Otherwise, consider any
          # error as fatal.
          raise html_error if html_error && (format || text_error)
          raise text_error if text_error && format

          [html, text]
        end

        def try_render(format, input)
          [render_view(format, input), nil]
        rescue Hanami::View::TemplateNotFoundError => exception
          [nil, exception]
        end
      end

      # Builder class for constructing default views.
      # Keeps view building logic separate from mailer instances.
      #
      # @api private
      class DefaultViewBuilder
        class << self
          # Builds a default view from exposures if Hanami::View is available.
          def call(mailer)
            view_class = mailer.class.config.view_class || Hanami::View

            # A view needs paths to find its templates. These may be configured on the mailer, or
            # inherited from an already-configured `view_class` (e.g. within a Hanami app).
            paths = mailer.class.config.paths
            if (paths.nil? || paths.empty?) && view_class.respond_to?(:config)
              paths = view_class.config.paths
            end
            return nil if paths.nil? || paths.empty?

            template = mailer.class.config.template
            template ||= inferred_template(mailer)

            build_view_class(
              view_class: view_class,
              template: template,
              exposures: mailer.class.exposures,
              config: mailer.class.config
            )
          end

          private

          # Infers template path from class name.
          #
          # @example
          #   Mailers::WelcomeMailer -> "mailers/welcome_mailer"
          def inferred_template(mailer)
            return nil unless mailer.class.name

            mailer.class.name
              .gsub("::", "/")
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .downcase
          end

          # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity

          # Builds a Hanami::View instance from the mailer's configuration.
          #
          # The view is a subclass of the mailer's configured `view_class`, so it inherits that
          # class's configuration. Only view settings the mailer has *explicitly* configured are
          # applied as overrides, leaving an already-configured base class (such as a Hanami app's
          # view) to provide its context, parts, scopes and helpers by inheritance. A standalone
          # mailer (whose `view_class` is the unconfigured `Hanami::View`) still drives its own
          # view via these overrides.
          def build_view_class(view_class:, template:, exposures:, config:)
            view_template = template
            view_exposures = exposures
            mailer_config = config

            built = Class.new(view_class) do
              Hanami::View.config._settings.each do |setting_def|
                name = setting_def.name

                # `template` and `layout` are handled explicitly below.
                next if name == :template || name == :layout
                next unless mailer_config.respond_to?(name)
                next unless mailer_config.configured?(name)

                self.config.public_send(:"#{name}=", mailer_config.public_send(name))
              end

              # Mailers do not use a layout by default, but one may be configured.
              self.config.layout = mailer_config.configured?(:layout) ? mailer_config.layout : false

              self.config.template = view_template if view_template

              view_exposures.each do |name, exposure|
                if exposure.proc
                  expose(name, **exposure.options, &exposure.proc)
                else
                  expose(name, **exposure.options)
                end
              end
            end

            built.new
          end
          # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity
        end
      end
    end
  end
end
