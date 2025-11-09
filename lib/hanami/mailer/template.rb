# frozen_string_literal: true

require "tilt"

module Hanami
  class Mailer
    # A logic-less template.
    #
    # @api private
    # @since 0.1.0
    #
    # TODO this is identical to Hanami::View, consider to move into Hanami::Utils
    class Template
      def initialize(template, encoding = Encoding::UTF_8)
        @_template = Tilt.new(template, default_encoding: encoding)
        freeze
      end

      # Render the template within the context of the given scope.
      #
      # @param scope [Object] the rendering scope
      # @param locals [Hash] set of objects passed to the constructor
      #
      # @return [String] the output of the rendering process
      #
      # @api private
      # @since 0.1.0
      def render(scope, locals = {})
        @_template.render(scope.dup, locals)
      end

      def render_layout(content, locals = {})
        @_template.render(nil, locals) { content }
      end
    end
  end
end
