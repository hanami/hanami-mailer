# frozen_string_literal: true

require "set"
require "hanami/utils/kernel"
require "hanami/mailer/template_name"
require "hanami/mailer/templates_finder"

module Hanami
  class Mailer
    # Framework configuration
    #
    # @since 0.1.0
    class Configuration
      # Default root
      #
      # @since 0.1.0
      # @api private
      DEFAULT_ROOT = "."

      # Default delivery method
      #
      # @since 0.1.0
      # @api private
      DEFAULT_DELIVERY_METHOD = :smtp

      # Default charset
      #
      # @since 0.1.0
      # @api private
      DEFAULT_CHARSET = "UTF-8"

      private_constant(*constants(false))

      # Initialize a configuration instance
      #
      # @yield [config] the new initialized configuration instance
      # @return [Hanami::Mailer::Configuration] a new configuration's instance
      #
      # @since 0.1.0
      #
      # @example Basic Usage
      #   require 'hanami/mailer'
      #
      #   configuration = Hanami::Mailer::Configuration.new do |config|
      #     config.delivery_method :smtp, ...
      #   end
      def initialize
        @mailers = {}

        self.namespace       = Object
        self.root            = DEFAULT_ROOT
        self.delivery_method = DEFAULT_DELIVERY_METHOD
        self.default_charset = DEFAULT_CHARSET

        yield(self) if block_given?
        @finder = TemplatesFinder.new(root)
      end

      # Set the Ruby namespace where to lookup for mailers.
      #
      # When multiple instances of the framework are used, we want to make sure
      # that if a `MyApp` wants a `Mailers::Signup` mailer, we are loading the
      # right one.
      #
      # @!attribute namespace
      #   @return [Class,Module,String] the Ruby namespace where the mailers
      #     are located
      #
      # @since next
      # @api unstable
      #
      # @example
      #   require 'hanami/mailer'
      #
      #   Hanami::Mailer::Configuration.new do |config|
      #     config.namespace = MyApp::Mailers
      #   end
      attr_accessor :namespace

      # Set the root path where to search for templates
      #
      # If not set, this value defaults to the current directory.
      #
      # @param value [String, Pathname] the root path for mailer templates
      #
      # @raise [Errno::ENOENT] if the path doesn't exist
      #
      # @since next
      # @api unstable
      #
      # @see http://www.ruby-doc.org/stdlib/libdoc/pathname/rdoc/Pathname.html
      # @see http://rdoc.info/gems/hanami-utils/Hanami/Utils/Kernel#Pathname-class_method
      #
      # @example
      #   require 'hanami/mailer'
      #
      #   Hanami::Mailer::Configuration.new do |config|
      #     config.root = 'path/to/templates'
      #   end
      def root=(value)
        @root = Utils::Kernel.Pathname(value).realpath
      end

      # @!attribute [r] root
      #   @return [Pathname] the root path for mailer templates
      #
      # @since next
      # @api unstable
      attr_reader :root

      # @param blk [Proc] the code block
      #
      # @return [void]
      #
      # @raise [ArgumentError] if called without passing a block
      #
      # @since 0.1.0
      #
      # @see Hanami::Mailer.configure
      def prepare(&blk)
        raise ArgumentError.new("Please provide a block") unless block_given?

        @modules.push(blk)
      end

      # Duplicate by copying the settings in a new instance.
      #
      # @return [Hanami::Mailer::Configuration] a copy of the configuration
      #
      # @since 0.1.0
      # @api private
      def duplicate
        Configuration.new.tap do |c|
          c.namespace  = namespace
          c.root       = root.dup
          c.modules    = modules.dup
          c.delivery_method = delivery_method
          c.default_charset = default_charset
        end
      end

      # Load the configuration
      def load!
        mailers.each { |m| m.__send__(:load!) }
        freeze
      end

      # Reset the configuration
      def reset!
        root(DEFAULT_ROOT)
        delivery_method(DEFAULT_DELIVERY_METHOD)
        default_charset(DEFAULT_CHARSET)

        @mailers = Set.new
        @modules = []
      end

      alias_method :unload!, :reset!

      # Copy the configuration for the given mailer
      #
      # @param base [Class] the target mailer
      #
      # @return void
      #
      # @since 0.1.0
      # @api private
      def copy!(base)
        modules.each do |mod|
          base.class_eval(&mod)
        end
      end

      # Specify a global delivery method for the mail gateway.
      #
      # It supports the following delivery methods:
      #
      #   * Exim (`:exim`)
      #   * Sendmail (`:sendmail`)
      #   * SMTP (`:smtp`, for local installations)
      #   * SMTP Connection (`:smtp_connection`,
      #     via `Net::SMTP` - for remote installations)
      #   * Test (`:test`, for testing purposes)
      #
      # The default delivery method is SMTP (`:smtp`).
      #
      # Custom delivery methods can be specified by passing the class policy and
      # a set of optional configurations. This class MUST respond to:
      #
      #   * `initialize(options = {})`
      #   * `deliver!(mail)`
      #
      # @param method [Symbol, #initialize, deliver!] delivery method
      # @param options [Hash] optional settings
      #
      # @return [Array] an array containing the delivery method and the optional settings as an Hash
      #
      # @since next
      # @api unstable
      #
      # @example Setup delivery method with supported symbol
      #   require 'hanami/mailer'
      #
      #   Hanami::Mailer::Configuration.new do |config|
      #     config.delivery_method = :sendmail
      #   end
      #
      # @example Setup delivery method with supported symbol and options
      #   require 'hanami/mailer'
      #
      #   Hanami::Mailer::Configuration.new do |config|
      #     config.delivery_method = :smtp, address: "localhost", port: 1025
      #   end
      #
      # @example Setup custom delivery method with options
      #   require 'hanami/mailer'
      #
      #   class MandrillDeliveryMethod
      #     def initialize(options)
      #       @options = options
      #     end
      #
      #     def deliver!(mail)
      #       # ...
      #     end
      #   end
      #
      #   Hanami::Mailer.Configuration.new do |config|
      #     config.delivery_method = MandrillDeliveryMethod,
      #                                username: ENV['MANDRILL_USERNAME'],
      #                                password: ENV['MANDRILL_API_KEY']
      #   end
      attr_accessor :delivery_method

      # Specify a default charset for all the delivered emails
      #
      # If not set, it defaults to `UTF-8`
      #
      # @!attribute default_charset
      #   @return [String] the charset
      #
      # @since next
      # @api unstable
      #
      # @example
      #   require 'hanami/mailer'
      #
      #   Hanami::Mailer::Configuration.new do |config|
      #     config.default_charset = "iso-8859-1"
      #   end
      attr_accessor :default_charset

      # Add a mailer to the registry
      #
      # @param mailer [Hanami::Mailer] a mailer
      #
      # @since 0.1.0
      # @api unstable
      def add_mailer(mailer)
        template_name = TemplateName[mailer.template_name, namespace]
        templates     = finder.find(template_name)

        mailers[mailer] = templates
      end

      # @param mailer [Hanami::Mailer] a mailer
      # @param format [Symbol] the wanted format (eg. `:html`, `:txt`)
      #
      # @raise [Hanami::Mailer::UnknownMailerError] if the given mailer is not
      #   present in the configuration. This happens when the configuration is
      #   used before to being finalized.
      #
      # @since next
      # @api unstable
      def template(mailer, format)
        mailers.fetch(mailer) { raise UnknownMailerError.new(mailer) }[format]
      end

      # @param mailer [Hanami::Mailer] a mailer
      # @param format [Symbol] the wanted format (eg. `:html`, `:txt`)
      #
      # @since next
      # @api unstable
      def layout(mailer, format)
        unless mailer.layout_name.nil?
          finder.find(mailer.layout_name)[format]
        end
      end

      # Returns a new updated instance of the mailer with the given settings.
      #
      # @yieldparam [Hanami::Mailer::Configuration] the new configuration instance
      #
      # @raise [LocalJumpError] if no block is given
      #
      # @since x.x.x
      # @api unstable
      #
      # @example
      #   require "hanami/mailer"
      #
      #   configuration = Hanami::Mailer::Configuration.new
      #   configuration.delivery_method # => :smtp
      #
      #   updated = configuration.with do |config|
      #     config.delivery_method = :test
      #   end
      #
      #   configuration.delivery_method # => :smtp
      #   updated.delivery_method       # => :test
      def with
        dup.tap do |new|
          yield(new)
          new.freeze
        end
      end

      # Deep freeze the important instance variables
      #
      # @since next
      # @api unstable
      def freeze
        delivery_method.freeze
        default_charset.freeze
        mailers.freeze
        super
      end

      private

      # @since 0.1.0
      # @api private
      attr_reader :mailers

      # @since next
      # @api unstable
      attr_reader :finder
    end
  end
end
