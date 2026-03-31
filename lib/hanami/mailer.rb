# frozen_string_literal: true

require "dry/configurable"
require "zeitwerk"

require_relative "mailer/errors"

module Hanami
  # Base mailer class
  #
  # @api public
  class Mailer
    # @api private
    def self.gem_loader
      @gem_loader ||= Zeitwerk::Loader.new.tap do |loader|
        root = File.expand_path("..", __dir__)
        loader.tag = "hanami-mailer"
        loader.push_dir(root)
        loader.ignore(
          "#{root}/hanami-mailer.rb",
          "#{root}/hanami/mailer/version.rb",
          "#{root}/hanami/mailer/errors.rb"
        )
        loader.inflector = Zeitwerk::GemInflector.new("#{root}/hanami-mailer.rb")
        loader.inflector.inflect(
          "dsl" => "DSL",
          "smtp" => "SMTP"
        )
      end
    end

    gem_loader.setup

    extend Dry::Configurable

    # Paths to search for static attachment files
    # @api public
    setting :attachment_paths, default: []

    # Include Hanami::View integration if available.
    # This wraps initialization to provide automatic view building from exposures.
    # The ViewIntegration module adds all view-related settings and capabilities.
    #
    # Attempt to require hanami-view so users don't need to worry about load order.
    # View-building behavior can be disabled per-class via `config.integrate_view = false`.
    begin
      require "hanami/view"
    rescue LoadError => exception
      raise unless exception.path == "hanami/view"
    end
    if defined?(Hanami::View)
      require_relative "mailer/view_integration"
      include ViewIntegration
    end

    # Standard email headers that have dedicated convenience methods
    # @api private
    STANDARD_HEADERS = %i[from to cc bcc reply_to return_path subject].freeze

    class << self
      # Helper method for creating Attachment objects
      #
      # This is a convenience method for creating Attachment objects
      # that can be passed to the `attachments:` parameter.
      #
      # @param filename [String] name of the file
      # @param content [String] file content
      # @param options [Hash] additional options (content_type, inline, etc.)
      #
      # @return [Attachment] attachment object
      #
      # @api public
      #
      # @example
      #   mailer.deliver(
      #     user: user,
      #     attachments: [
      #       Hanami::Mailer.file("invoice.pdf", pdf_bytes, content_type: "application/pdf")
      #     ]
      #   )
      def file(filename, content, content_type: nil, inline: false)
        Attachment.new(filename:, content:, content_type:, inline:)
      end
    end

    class << self
      # Define a header field
      #
      # Can be called with:
      # - A static value: `header :from, "noreply@example.com"`
      # - A static value with proper casing: `header "X-Priority", "1"`
      # - A proc/block: `header(:to) { |user_email:| user_email }`
      #
      # Procs receive keyword arguments from the merged input and exposures context.
      #
      # Header names:
      # - Symbols with underscores (e.g., :x_priority) are converted to Title-Case (X-Priority)
      # - Strings are passed through as-is, preserving casing
      # - Use strings for full control over casing
      #
      # @param field_name [Symbol, String] the header field name
      # @param value [Object, nil] optional static value
      # @param block [Proc] optional block for computing the value
      #
      # @api public
      def header(field_name, value = nil, &block)
        headers.add(field_name, block, default: value)
      end

      # Define header fields: from, to, cc, bcc, reply_to, return_path, subject
      #
      # Each method can be called with:
      # - A static value: `from "noreply@example.com"`
      # - A proc/block: `to { |user_email:| user_email }`
      #
      # Procs receive keyword arguments from the merged input and exposures context.
      #
      # @api public
      STANDARD_HEADERS.each do |field_name|
        define_method(field_name) do |value = nil, &block|
          header(field_name, value, &block)
        end
      end

      # @api private
      def headers
        @headers ||= DSL::Exposures.new
      end

      # Define template data exposures
      #
      # @param names [Array<Symbol>] exposure names
      # @param proc [Proc] optional block for computing the value
      #
      # @api public
      def expose(*names, **options, &block)
        if names.length == 1
          exposures.add(names.first, block, **options)
        else
          names.each { |name| exposures.add(name, nil, **options) }
        end
      end

      # @api private
      def exposures
        @exposures ||= DSL::Exposures.new
      end

      # Define an attachment
      #
      # @param name_or_filename [Symbol, String] method name or static filename
      # @param proc [Proc] optional block for computing attachment
      #
      # @api public
      def attachment(name_or_filename = nil, **options, &block)
        attachments.add(name_or_filename, block, **options)
      end

      # @api private
      def attachments
        @attachments ||= DSL::Attachments.new
      end

      # Define a delivery option
      #
      # Delivery options are delivery-method-specific parameters that can be used
      # to customize how a message is sent. For example, a third-party email service
      # might support scheduled sending, priority levels, or tracking options.
      #
      # @param name [Symbol] the option name
      # @param value [Object, nil] optional static value
      # @param block [Proc] optional block for computing the value
      #
      # @api public
      #
      # @example Static value
      #   delivery_option :track_opens, true
      #
      # @example Dynamic value with block
      #   delivery_option :send_at do |scheduled_time:|
      #     scheduled_time
      #   end
      def delivery_option(name, value = nil, &block)
        delivery_options.add(name, block, default: value)
      end

      # @api private
      def delivery_options
        @delivery_options ||= DSL::Exposures.new
      end

      # @api private
      def inherited(subclass)
        super

        subclass.instance_variable_set(:@headers, headers.dup)
        subclass.instance_variable_set(:@exposures, exposures.dup)
        subclass.instance_variable_set(:@attachments, attachments.dup)
        subclass.instance_variable_set(:@delivery_options, delivery_options.dup)
      end
    end

    # @api private
    attr_reader :view, :delivery_method

    # Initialize a new mailer instance
    #
    # @param view [Object, nil] optional view object for rendering
    # @param delivery_method [Object] delivery method (defaults to Test delivery)
    #
    # @api public
    def initialize(view: nil, delivery_method: nil)
      @view = view
      @delivery_method = delivery_method || default_delivery_method
    end

    # Deliver the email
    #
    # @param headers [Hash] optional header overrides (from, to, cc, bcc, reply_to, return_path, subject)
    # @param attachments [Array<Hash, Attachment>, nil] optional runtime attachments
    # @param format [Symbol, nil] optional format to render (:html or :text)
    # @param input [Hash] input data for exposures and rendering
    #
    # @return [Delivery::Result]
    #
    # @api public
    def deliver(headers: {}, attachments: nil, format: nil, **input)
      message = prepare(headers:, attachments:, format:, **input)
      delivery_method.call(message)
    end

    # rubocop:disable Metrics/AbcSize

    # Build the message without delivering it
    #
    # @param headers [Hash] optional header overrides (from, to, cc, bcc, reply_to, return_path, subject)
    # @param attachments [Array<Hash, Attachment>, nil] optional runtime attachments
    # @param format [Symbol, nil] optional format to render (:html or :text)
    # @param input [Hash] input data for exposures and rendering
    #
    # @return [Message]
    #
    # @api public
    def prepare(headers: {}, attachments: nil, format: nil, **input)
      # Collect header overrides
      header_overrides = headers.compact

      # Evaluate exposures
      locals = self.class.exposures.bind(self).call(input)

      # Merge input with evaluated locals for use in header evaluation
      context = input.merge(locals)

      # Evaluate headers (from, to, cc, bcc, reply_to, return_path, subject, and custom headers)
      headers = self.class.headers.bind(self).call(context)

      # Merge with overrides, giving precedence to explicit arguments
      headers = headers.merge(header_overrides)

      # Separate standard headers from custom headers
      custom_headers = headers.reject { |key, _| STANDARD_HEADERS.include?(key) }

      # Normalize custom header names to proper casing
      normalized_custom_headers = custom_headers.transform_keys { |key| normalize_header_name(key) }

      # Render body
      html_body, text_body = render(input, format:)

      # Evaluate class-level attachments and merge with runtime attachments
      runtime_attachments = attachments
      attachments = self.class.attachments
        .bind(self, context)
        .concat(runtime_attachments)
        .to_a

      delivery_options = self.class.delivery_options.bind(self).call(context)

      # Build message
      Message.new(
        from: headers[:from],
        to: headers[:to],
        cc: headers[:cc],
        bcc: headers[:bcc],
        reply_to: headers[:reply_to],
        return_path: headers[:return_path],
        subject: headers[:subject],
        html_body:,
        text_body:,
        attachments: attachments,
        headers: normalized_custom_headers,
        delivery_options:
      )
    end
    # rubocop:enable Metrics/AbcSize

    # Helper method for creating attachments in attachment blocks
    #
    # Returns an Attachment object that provides a structured, validated
    # way to define attachment data instead of using raw hashes.
    #
    # @param filename [String] name of the file
    # @param content [String] file content
    # @param options [Hash] additional options (content_type, inline, etc.)
    #
    # @return [Attachment] attachment object
    #
    # @api public
    #
    # @example
    #   attachment :invoice do |invoice:|
    #     file("invoice-#{invoice.number}.pdf", invoice.to_pdf, content_type: "application/pdf")
    #   end
    def file(...)
      self.class.file(...)
    end

    private

    # Renders and returns HTML and text bodies.
    def render(input, format: nil)
      html_body = render_view(:html, input) if format.nil? || format == :html
      text_body = render_view(:text, input) if format.nil? || format == :text
      [html_body, text_body]
    end

    # Renders body for a specific format.
    def render_view(format, input)
      return unless view

      view.call(format:, **input).to_s
    end

    def default_delivery_method
      Delivery::Test.new
    end

    # Normalizes header names to proper email header casing.
    def normalize_header_name(name)
      return name if name.is_a?(String)

      # Convert symbol to string and apply Title-Case with dashes
      # e.g., :x_priority => "X-Priority"
      #       :list_unsubscribe => "List-Unsubscribe"
      name.to_s
        .split("_")
        .map(&:capitalize)
        .join("-")
    end
  end
end
