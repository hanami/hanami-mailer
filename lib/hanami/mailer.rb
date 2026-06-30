# frozen_string_literal: true

require "dry/configurable"
require "zeitwerk"

require_relative "mailer/errors"

module Hanami
  # Base mailer class
  #
  # @api public
  # @since 3.0.0
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
    # @since 3.0.0
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
      # @since 3.0.0
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
      # - A proc/block: `header(:to) { |recipient| recipient[:email] }`
      #
      # A block's parameters follow the same convention as everywhere in the mailer:
      #
      # - Positional parameters receive exposure values, matched by name.
      # - Keyword parameters receive matching keys from the `deliver` input.
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
      # @since 3.0.0
      def header(field_name, value = nil, &block)
        headers.add(field_name, block, default: value)
      end

      # Define header fields: from, to, cc, bcc, reply_to, return_path, subject
      #
      # Each method can be called with:
      # - A static value: `from "noreply@example.com"`
      # - A proc/block: `to { |recipient| recipient[:email] }`
      #
      # As with {#header}, a block's positional parameters receive exposure values and its keyword
      # parameters receive matching keys from the `deliver` input.
      #
      # @api public
      # @since 3.0.0
      STANDARD_HEADERS.each do |field_name|
        define_method(field_name) do |value = nil, &block|
          header(field_name, value, &block)
        end
      end

      # @api private
      def headers
        @headers ||= DSL::Exposures.new
      end

      # Defines one or more values to expose to the template.
      #
      # An exposure's value comes from the first of these that applies:
      #
      # 1. The given block (single name only).
      # 2. An instance method matching the name.
      # 3. The matching key in the input given to {#call}, or the `:default`
      #    option if the input has no such key.
      #
      # When a block or method provides the value, its parameters determine what
      # it receives:
      #
      # - Positional parameters receive other exposures' values, matched by name.
      # - Keyword parameters receive matching keys from the input. Give them
      #   defaults to make those input keys optional.
      # - A keyword splat (`**input`) receives the entire input.
      #
      # Pass several names to expose multiple values at once; the options then
      # apply to every named exposure. A block may only be given for a single
      # name.
      #
      # @example A value computed by a block
      #   expose :greeting do |user:|
      #     "Hello, #{user.name}"
      #   end
      #
      # @example A value from a matching instance method, or passed through from the input
      #   expose :user
      #
      # @example Multiple values passed through from the input
      #   expose :user, :order
      #
      # @param names [Array<Symbol>] the exposure names
      # @param options [Hash] options applied to the exposure(s)
      # @option options [Object] :default value to use when the input has no
      #   matching key (pass-through exposures only)
      # @option options [Boolean] :private withhold from the view, while keeping
      #   the value available as a dependency to other exposures, headers,
      #   attachments, and delivery options (defaults to false)
      # @param block [Proc] block computing the value (single name only)
      #
      # @api public
      # @since 3.0.0
      def expose(*names, **options, &block)
        if names.length == 1
          exposures.add(names.first, block, **options)
        else
          names.each { |name| exposures.add(name, nil, **options) }
        end
      end

      # Defines one or more private exposures.
      #
      # A private exposure is computed and stays available as a dependency to other exposures, and
      # to the mailer's headers, attachments, and delivery options, but is never passed to the view
      # for rendering. This is a shorthand for `expose(..., private: true)`.
      #
      # @see #expose
      #
      # @api public
      # @since 3.0.0
      def private_expose(*names, **options, &block)
        expose(*names, **options, private: true, &block)
      end

      # @api private
      def exposures
        @exposures ||= DSL::Exposures.new
      end

      # Define an attachment
      #
      # An attachment block returns one or more attachment objects (use the {#file} helper). As with
      # {#header}, its positional parameters receive exposure values and its keyword parameters
      # receive matching keys from the `deliver` input.
      #
      # @param name_or_filename [Symbol, String] method name or static filename
      # @param proc [Proc] optional block for computing attachment
      #
      # @api public
      # @since 3.0.0
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
      # As with {#header}, a block's positional parameters receive exposure values and its keyword
      # parameters receive matching keys from the `deliver` input.
      #
      # @param name [Symbol] the option name
      # @param value [Object, nil] optional static value
      # @param block [Proc] optional block for computing the value
      #
      # @api public
      # @since 3.0.0
      #
      # @example Static value
      #   delivery_option :track_opens, true
      #
      # @example Value computed from the input (keyword parameter)
      #   delivery_option :send_at do |scheduled_time:|
      #     scheduled_time
      #   end
      #
      # @example Value computed from an exposure (positional parameter)
      #   delivery_option :priority do |user_type|
      #     user_type == "premium" ? "high" : "normal"
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
    # @since 3.0.0
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
    # @since 3.0.0
    def deliver(headers: {}, attachments: nil, format: nil, **input)
      message = prepare(headers:, attachments:, format:, **input)
      delivery_method.call(message)
    end

    # Previews the email without delivering it
    #
    # Builds the message and passes it to the delivery method's `preview` hook, returning whatever
    # that returns. The default (and test) delivery method returns the message unchanged; a
    # third-party delivery method can override `preview` to apply service-specific logic.
    #
    # @param headers [Hash] optional header overrides (from, to, cc, bcc, reply_to, return_path, subject)
    # @param attachments [Array<Hash, Attachment>, nil] optional runtime attachments
    # @param format [Symbol, nil] optional format to render (:html or :text)
    # @param input [Hash] input data for exposures and rendering
    #
    # @return [Message]
    #
    # @api public
    # @since 3.0.0
    def preview(headers: {}, attachments: nil, format: nil, **input)
      message = prepare(headers:, attachments:, format:, **input)
      delivery_method.preview(message)
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
    # @since 3.0.0
    def prepare(headers: {}, attachments: nil, format: nil, **input)
      # Evaluate exposures as our "locals". These will be provided as the _depdenencies_ (available
      # via positional params) to all our other class-level exposure-like APIs: headers,
      # attachments, and delivery options.
      locals = self.class.exposures.bind(self).call(input)

      # Evaluate class-level headers, giving precdence to headers given as explicit arguments.
      header_overrides = headers.compact
      headers = self.class.headers
        .bind(self)
        .call(input, dependencies: locals)
        .merge(header_overrides)

      # Extract custom headers and normalize their header names to proper casing.
      custom_headers = headers
        .reject { |key, _| STANDARD_HEADERS.include?(key) }
        .transform_keys { |key| normalize_header_name(key) }

      # Render bodies. Private exposures are available to the methods above as dependencies, but are
      # withheld from the view.
      html_body, text_body = render(self.class.exposures.reject_private(locals), format:)

      # Evaluate class-level attachments and merge with runtime attachments.
      runtime_attachments = attachments
      attachments = self.class.attachments
        .bind(self)
        .call(input, dependencies: locals)
        .concat(runtime_attachments)
        .to_a

      # Evaluate delivery options.
      delivery_options = self.class.delivery_options.bind(self).call(input, dependencies: locals)

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
        headers: custom_headers,
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
    # @since 3.0.0
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
