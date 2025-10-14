# frozen_string_literal: true

require "dry/configurable"
require "mail"
require "concurrent"
require "zeitwerk"

# Hanami
#
# @since 0.1.0
module Hanami
  # Hanami::Mailer
  #
  # @since 0.1.0
  class Mailer
    def self.gem_loader
      @gem_loader ||= Zeitwerk::Loader.new.tap do |loader|
        root =  File.expand_path("..", __dir__)
        loader.tag = "hanami-mailer"
        loader.push_dir(root)
        loader.ignore(
          "#{root}/hanami/mailer.rb",
          "#{root}/hanami/mailer/version.rb",
        )
      end
    end

    gem_loader.setup

    require "hanami/mailer/version"
    require "hanami/mailer/template"
    require "hanami/mailer/finalizer"
    require "hanami/mailer/configuration"
    require "hanami/mailer/dsl"

    # Content types mapping
    #
    # @since 0.1.0
    # @api private
    CONTENT_TYPES = {
      html: "text/html",
      txt: "text/plain"
    }.freeze

    private_constant(:CONTENT_TYPES)

    # Base error for Hanami::Mailer
    #
    # @since 0.1.0
    class Error < ::StandardError
    end

    # Unknown mailer
    #
    # This error is raised at the runtime when trying to deliver a mail message,
    # by using a configuration that it wasn't finalized yet.
    #
    # @since next
    # @api unstable
    #
    # @see Hanami::Mailer.finalize
    class UnknownMailerError < Error
      # @param mailer [Hanami::Mailer] a mailer
      #
      # @since next
      # @api unstable
      def initialize(mailer)
        super("Unknown mailer: #{mailer.inspect}. Please finalize the configuration before to use it.")
      end
    end

    # Missing delivery data error
    #
    # It's raised when a mailer doesn't specify `from` or `to`.
    #
    # @since 0.1.0
    class MissingDeliveryDataError < Error
      def initialize
        super("Missing delivery data, please check 'from', or 'to'")
      end
    end

    # @since next
    # @api unstable
    @_subclasses = Concurrent::Array.new

    # Override Ruby's hook for modules.
    # It includes basic `Hanami::Mailer` modules to the given Class.
    # It sets a copy of the framework configuration
    #
    # @param base [Class] the target mailer
    #
    # @since next
    # @api unstable
    def self.inherited(base)
      super
      @_subclasses.push(base)
      base.extend Dsl
    end

    private_class_method :inherited

    # Finalize the configuration
    #
    # This should be used before to start to use the mailers
    #
    # @param configuration [Hanami::Mailer::Configuration] the configuration to
    #   finalize
    #
    # @return [Hanami::Mailer::Configuration] the finalized configuration
    #
    # @since next
    # @api unstable
    #
    # @example
    #   require 'hanami/mailer'
    #
    #   configuration = Hanami::Mailer::Configuration.new do |config|
    #     # ...
    #   end
    #
    #   configuration = Hanami::Mailer.finalize(configuration)
    #   MyMailer.new(configuration: configuration)
    def self.finalize(configuration)
      Finalizer.finalize(@_subclasses, configuration)
    end

    # Initialize a mailer
    #
    # @param configuration [Hanami::Mailer::Configuration] the configuration
    # @return [Hanami::Mailer]
    #
    # @since 0.1.0
    def initialize(configuration:)
      @configuration = configuration
      freeze
    end

    # Prepare the email message when a new mailer is initialized.
    #
    # @return [Mail::Message] the delivered email
    #
    # @since 0.1.0
    # @api unstable
    #
    # @see Hanami::Mailer::Configuration#default_charset
    #
    # @example
    #   require 'hanami/mailer'
    #
    #   configuration = Hanami::Mailer::Configuration.new do |config|
    #     config.delivery_method = :smtp
    #   end
    #
    #   configuration = Hanami::Mailer.finalize(configuration)
    #
    #   module Billing
    #     class InvoiceMailer < Hanami::Mailer
    #       from    'noreply@example.com'
    #       to      ->(locals) { locals.fetch(:user).email }
    #       subject ->(locals) { "Invoice number #{locals.fetch(:invoice).number}" }
    #
    #       before do |mail, locals|
    #         mail.attachments["invoice-#{locals.fetch(:invoice).number}.pdf"] =
    #           File.read('/path/to/invoice.pdf')
    #       end
    #     end
    #   end
    #
    #   invoice = Invoice.new(number: 23)
    #   user    = User.new(name: 'L', email: 'user@example.com')
    #
    #   mailer = Billing::InvoiceMailer.new(configuration: configuration)
    #
    #   # Deliver both text, HTML parts and the attachment
    #   mailer.deliver(invoice: invoice, user: user)
    #
    #   # Deliver only the text part and the attachment
    #   mailer.deliver(invoice: invoice, user: user, format: :txt)
    #
    #   # Deliver only the text part and the attachment
    #   mailer.deliver(invoice: invoice, user: user, format: :html)
    #
    #   # Deliver both the parts with "iso-8859"
    #   mailer.deliver(invoice: invoice, user: user, charset: 'iso-8859')
    def deliver(locals)
      mail(locals).deliver
    rescue ArgumentError => exception
      raise MissingDeliveryDataError if exception.message =~ /SMTP (From|To) address/

      raise
    end

    # @since next
    # @api unstable
    alias_method :call, :deliver

    # Render a single template with the specified format.
    #
    # @param format [Symbol] format
    #
    # @return [String] the output of the rendering process.
    #
    # @since 0.1.0
    # @api unstable
    def render(format, locals)
      template(format).render(self, locals)
    end

    private

    # @api unstable
    # @since next
    attr_reader :configuration

    # @api unstable
    # @since next
    def mail(locals)
      Mail.new.tap do |mail|
        instance_exec(mail, locals, &self.class.before)
        bind(mail, locals)
      end
    end

    # @api unstable
    # @since next
    #
    def bind(mail, locals) # rubocop:disable Metrics/AbcSize
      charset = locals.fetch(:charset, configuration.default_charset)

      mail.return_path = __dsl(:return_path, locals)
      mail.from        = __dsl(:from,        locals)
      mail.to          = __dsl(:to,          locals)
      mail.cc          = __dsl(:cc,          locals)
      mail.bcc         = __dsl(:bcc,         locals)
      mail.reply_to    = __dsl(:reply_to,    locals)
      mail.subject     = __dsl(:subject,     locals)

      mail.html_part = __part(:html, charset, locals)
      mail.text_part = __part(:txt,  charset, locals)

      mail.charset = charset
      mail.delivery_method(*configuration.delivery_method)
    end

    # @since next
    # @api unstable
    def template(format)
      configuration.template(self.class, format)
    end

    # @since 0.1.0
    # @api unstable
    def __dsl(method_name, locals)
      case result = self.class.__send__(method_name)
      when Proc
        result.call(locals)
      else
        result
      end
    end

    # @since 0.1.0
    # @api unstable
    def __part(format, charset, locals)
      return unless __part?(format, locals)

      Mail::Part.new.tap do |part|
        part.content_type = "#{CONTENT_TYPES.fetch(format)}; charset=#{charset}"
        part.body         = render(format, locals)
      end
    end

    # @since 0.1.0
    # @api unstable
    def __part?(format, locals)
      wanted = locals.fetch(:format, nil)
      wanted == format ||
        (!wanted && !template(format).nil?)
    end
  end
end
