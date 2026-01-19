# frozen_string_literal: true

require "dry/configurable"
require "zeitwerk"

require_relative "mailer/errors"
require_relative "mailer/attachment_data"

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

    # Prepend Hanami::View integration if available.
    # This wraps initialization to provide automatic view building from exposures.
    # The ViewIntegration module adds all view-related settings and capabilities.
    #
    # Note: When Hanami.bundled?("hanami-view") becomes available, we can use that instead of
    # defined?(Hanami::View) for a more robust check.
    if defined?(Hanami::View)
      require_relative "mailer/view_integration"
      include ViewIntegration
    end

    # Standard email headers that have dedicated convenience methods
    # @api private
    STANDARD_HEADERS = %i[from to cc bcc reply_to return_path subject].freeze

    class << self
      # Helper method for creating attachment data objects
      #
      # This is a convenience method for creating AttachmentData objects
      # that can be passed to the `attachments:` parameter.
      #
      # @param filename [String] name of the file
      # @param content [String] file content
      # @param options [Hash] additional options (content_type, inline, etc.)
      #
      # @return [AttachmentData] attachment data object
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
      def file(filename, content, **options)
        AttachmentData.new(
          filename: filename,
          content: content,
          content_type: options[:content_type],
          inline: options[:inline] || false
        )
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

      # @api private
      def inherited(subclass)
        super

        subclass.instance_variable_set(:@headers, headers.dup)
        subclass.instance_variable_set(:@exposures, exposures.dup)
        subclass.instance_variable_set(:@attachments, attachments.dup)
      end
    end
    # @api private
    attr_reader :view, :delivery

    # Initialize a new mailer instance
    #
    # @param view [Object, nil] optional view object for rendering
    # @param delivery [Object] delivery method (defaults to Test delivery)
    #
    # @api public
    def initialize(view: nil, delivery: nil)
      @view = view
      @delivery = delivery || default_delivery
    end

    # Deliver the email
    #
    # @param headers [Hash] optional header overrides (from, to, cc, bcc, reply_to, subject)
    # @param attachments [Array<Hash, AttachmentData>, nil] optional runtime attachments
    # @param input [Hash] input data for exposures and rendering
    #
    # @return [Mail::Message]
    #
    # @api public
    def deliver(headers: {}, attachments: nil, **input)
      message = prepare(headers: headers, attachments: attachments, **input)
      delivery.call(message)
    end

    # rubocop:disable Metrics/AbcSize

    # Build the message without delivering it
    #
    # @param headers [Hash] optional header overrides (from, to, cc, bcc, reply_to, subject)
    # @param attachments [Array<Hash, AttachmentData>, nil] optional runtime attachments
    # @param input [Hash] input data for exposures and rendering
    #
    # @return [Message]
    #
    # @api public
    def prepare(headers: {}, attachments: nil, **input)
      # Collect header overrides (compact to remove nil values)
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
      html_body = render_html(input)
      text_body = render_text(input)

      # Evaluate class-level attachments
      attachment_data = self.class.attachments.bind(self, context)
      attachment_objects = attachment_data.map do |data|
        Attachment.new(
          filename: data[:filename],
          content: read_attachment_content(data[:content], static: data[:static]),
          content_type: data[:content_type],
          inline: data[:inline]
        )
      end

      # Add runtime attachments
      if attachments
        runtime_attachments = process_runtime_attachments(attachments)
        attachment_objects.concat(runtime_attachments)
      end

      # Check for duplicate filenames
      ensure_unique_attachments attachment_objects

      # Build message
      Message.new(
        from: headers[:from],
        to: headers[:to],
        cc: headers[:cc],
        bcc: headers[:bcc],
        reply_to: headers[:reply_to],
        return_path: headers[:return_path],
        subject: headers[:subject],
        html_body: html_body,
        text_body: text_body,
        attachments: attachment_objects,
        headers: normalized_custom_headers
      )
    end
    # rubocop:enable Metrics/AbcSize

    # Helper method for creating attachments in attachment blocks
    #
    # Returns an AttachmentData object that provides a structured, validated
    # way to define attachment data instead of using raw hashes.
    #
    # @param filename [String] name of the file
    # @param content [String] file content
    # @param options [Hash] additional options (content_type, inline, etc.)
    #
    # @return [AttachmentData] attachment data object
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

    # Render HTML body
    #
    # @param input [Hash] input data for rendering
    # @return [String, nil]
    # @api private
    def render_html(input)
      render_view(:html, input)
    end

    # Render plain text body
    #
    # @param input [Hash] input data for rendering
    # @return [String, nil]
    # @api private
    def render_text(input)
      render_view(:txt, input)
    end

    # Render body for a specific format
    #
    # @param format [Symbol] the format to render (:html, :txt)
    # @param input [Hash] input data for rendering
    # @return [String, nil]
    # @api private
    def render_view(format, input)
      # TODO: should this be overridden by view integration? I'm thinking actually yes.
      return unless view

      view.call(format:, **input).to_s
    rescue StandardError
      # TODO: need better checking here
      # Template might not exist for this format
      nil
    end

    def read_attachment_content(content, static: false)
      # If content is a file path string, search for it in attachment_paths
      if content.is_a?(String) && static
        file_path = find_attachment_file(content)
        if file_path
          File.read(file_path)
        else
          # Static attachment file not found - raise error
          raise MissingAttachmentError.new(content, self.class.config.attachment_paths)
        end
      else
        content
      end
    end

    def find_attachment_file(filename)
      # If attachment_paths is configured, search there
      if self.class.config.attachment_paths.any?
        self.class.config.attachment_paths.each do |path|
          full_path = File.join(path, filename)
          return full_path if File.exist?(full_path)
        end
        nil
      else
        # Fall back to checking if the filename itself is a valid path
        File.exist?(filename) ? filename : nil
      end
    end

    def default_delivery
      Delivery::Test.new
    end

    # Normalize header names to proper email header casing
    #
    # @param name [Symbol, String] the header name
    # @return [String] properly cased header name
    #
    # @api private
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

    # Process runtime attachments into Attachment objects
    #
    # @param attachments [Array<Hash, AttachmentData>] runtime attachments
    # @return [Array<Attachment>]
    #
    # @api private
    def process_runtime_attachments(attachments)
      Array(attachments).map do |attachment|
        data = if attachment.is_a?(AttachmentData)
          attachment
        else
          begin
            AttachmentData.new(**attachment)
          rescue ArgumentError => e
            # Re-raise with clearer message for missing keywords
            if e.message.include?("missing keyword")
              keyword = e.message[/missing keyword: :?(\w+)/, 1]
              raise ArgumentError, "#{keyword} is required"
            else
              raise
            end
          end
        end

        Attachment.new(
          filename: data.filename,
          content: data.content,
          content_type: data.content_type,
          inline: data.inline
        )
      end
    end

    # Validate that all attachment filenames are unique
    #
    # @param attachments [Array<Attachment>] all attachments
    # @raise [DuplicateAttachmentError] if duplicate filenames are found
    #
    # @api private
    def ensure_unique_attachments(attachments)
      filenames = attachments.map(&:filename)
      duplicates = filenames.select { |filename| filenames.count(filename) > 1 }.uniq

      raise DuplicateAttachmentError, duplicates.first if duplicates.any?
    end
  end
end
