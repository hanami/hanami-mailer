# frozen_string_literal: true

module Hanami
  # Hanami::Mailer
  #
  # @since 0.1.0
  class Mailer
    require "hanami/mailer/template_name"

    # Class level DSL
    #
    # @since 0.1.0
    module Dsl
      # @since 0.3.0
      # @api unstable
      def self.extended(base)
        base.class_eval do
          @from        = nil
          @to          = nil
          @cc          = nil
          @bcc         = nil
          @reply_to    = nil
          @return_path = nil
          @subject     = nil
          @template    = nil
          @layout      = nil
          @before      = ->(*) {}
        end
      end

      private_class_method :extended

      # Sets the sender for mail messages
      #
      # It accepts a hardcoded value as a string, or a symbol that represents
      # an instance method for more complex logic.
      #
      # This value MUST be set, otherwise an exception is raised at the delivery
      # time.
      #
      # When a value is given, specify the sender of the email
      # Otherwise, it returns the sender of the email
      #
      # This is part of a DSL, for this reason when this method is called with
      # an argument, it will set the corresponding class variable. When
      # called without, it will return the already set value, or the default.
      #
      # @overload from(value)
      #   Sets the sender
      #   @param value [String, Symbol] the hardcoded value or method name
      #   @return [NilClass]
      #
      # @overload from
      #   Returns the sender
      #   @return [String, Symbol] the sender
      #
      # @since 0.1.0
      #
      # @example Hardcoded value (String)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     from "noreply@example.com"
      #   end
      #
      # @example Lazy (Proc)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     from ->(locals) { locals.fetch(:sender).email }
      #   end
      def from(value = nil)
        if value.nil?
          @from
        else
          @from = value
        end
      end

      # Sets the recipient for mail messages
      #
      # It accepts a hardcoded value as a string or array of strings.
      # For dynamic values, you can specify a symbol that represents an instance
      # method.
      #
      # This value MUST be set, otherwise an exception is raised at the delivery
      # time.
      #
      # When a value is given, specify the recipient of the email
      # Otherwise, it returns the recipient of the email
      #
      # This is part of a DSL, for this reason when this method is called with
      # an argument, it will set the corresponding class variable. When
      # called without, it will return the already set value, or the default.
      #
      # @overload to(value)
      #   Sets the recipient
      #   @param value [String, Array, Symbol] the hardcoded value or method name
      #   @return [NilClass]
      #
      # @overload to
      #   Returns the recipient
      #   @return [String, Array, Symbol] the recipient
      #
      # @since 0.1.0
      #
      # @example Hardcoded value (String)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     to "user@example.com"
      #   end
      #
      # @example Hardcoded value (Array)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     to ["user-1@example.com", "user-2@example.com"]
      #   end
      #
      # @example Lazy value (Proc)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     to ->(locals) { locals.fetch(:user).email }
      #   end
      #
      #   user = User.new(name: 'L')
      #   WelcomeMailer.new(configuration: configuration).deliver(user: user)
      #
      # @example Lazy values (Proc)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     to ->(locals) { locals.fetch(:users).map(&:email) }
      #   end
      #
      #   users = [User.new(name: 'L'), User.new(name: 'MG')]
      #   WelcomeMailer.new(configuration: configuration).deliver(users: users)
      def to(value = nil)
        if value.nil?
          @to
        else
          @to = value
        end
      end

      # Sets the cc (carbon copy) for mail messages
      #
      # It accepts a hardcoded value as a string or array of strings.
      # For dynamic values, you can specify a symbol that represents an instance
      # method.
      #
      # This value is optional.
      #
      # When a value is given, it specifies the cc for the email.
      # When a value is not given, it returns the cc of the email.
      #
      # This is part of a DSL, for this reason when this method is called with
      # an argument, it will set the corresponding class variable. When
      # called without, it will return the already set value, or the default.
      #
      # @overload cc(value)
      #   Sets the cc
      #   @param value [String, Array, Symbol] the hardcoded value or method name
      #   @return [NilClass]
      #
      # @overload cc
      #   Returns the cc
      #   @return [String, Array, Symbol] the recipient
      #
      # @since 0.3.0
      #
      # @example Hardcoded value (String)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     cc "other.user@example.com"
      #   end
      #
      # @example Hardcoded value (Array)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     cc ["other.user-1@example.com", "other.user-2@example.com"]
      #   end
      #
      # @example Lazy value (Proc)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     cc ->(locals) { locals.fetch(:user).email }
      #   end
      #
      #   user = User.new(name: 'L')
      #   WelcomeMailer.new(configuration: configuration).deliver(user: user)
      #
      # @example Lazy values (Proc)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     cc ->(locals) { locals.fetch(:users).map(&:email) }
      #   end
      #
      #   users = [User.new(name: 'L'), User.new(name: 'MG')]
      #   WelcomeMailer.new(configuration: configuration).deliver(users: users)
      def cc(value = nil)
        if value.nil?
          @cc
        else
          @cc = value
        end
      end

      # Sets the bcc (blind carbon copy) for mail messages
      #
      # It accepts a hardcoded value as a string or array of strings.
      # For dynamic values, you can specify a symbol that represents an instance
      # method.
      #
      # This value is optional.
      #
      # When a value is given, it specifies the bcc for the email.
      # When a value is not given, it returns the bcc of the email.
      #
      # This is part of a DSL, for this reason when this method is called with
      # an argument, it will set the corresponding class variable. When
      # called without, it will return the already set value, or the default.
      #
      # @overload bcc(value)
      #   Sets the bcc
      #   @param value [String, Array, Symbol] the hardcoded value or method name
      #   @return [NilClass]
      #
      # @overload bcc
      #   Returns the bcc
      #   @return [String, Array, Symbol] the recipient
      #
      # @since 0.3.0
      #
      # @example Hardcoded value (String)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     bcc "other.user@example.com"
      #   end
      #
      # @example Hardcoded value (Array)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     bcc ["other.user-1@example.com", "other.user-2@example.com"]
      #   end
      #
      # @example Lazy value (Proc)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     bcc ->(locals) { locals.fetch(:user).email }
      #   end
      #
      #   user = User.new(name: 'L')
      #   WelcomeMailer.new(configuration: configuration).deliver(user: user)
      #
      # @example Lazy values (Proc)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     bcc ->(locals) { locals.fetch(:users).map(&:email) }
      #   end
      #
      #   users = [User.new(name: 'L'), User.new(name: 'MG')]
      #   WelcomeMailer.new(configuration: configuration).deliver(users: users)
      def bcc(value = nil)
        if value.nil?
          @bcc
        else
          @bcc = value
        end
      end

      # Sets the reply_to for mail messages
      #
      # It accepts a hardcoded value as a string or array of strings.
      # For dynamic values, you can specify a symbol that represents an instance
      # method.
      #
      # This value is optional.
      #
      # When a value is given, it specifies the reply_to for the email.
      # When a value is not given, it returns the reply_to of the email.
      #
      # This is part of a DSL, for this reason when this method is called with
      # an argument, it will set the corresponding class variable. When
      # called without, it will return the already set value, or the default.
      #
      # @overload reply_to(value)
      #   Sets the reply_to
      #   @param value [String, Array, Symbol] the hardcoded value or method name
      #   @return [NilClass]
      #
      # @overload reply_to
      #   Returns the reply_to
      #   @return [String, Array, Symbol] the recipient
      #
      # @since 1.3.0
      #
      # @example Hardcoded value (String)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer
      #     include Hanami::Mailer
      #
      #     to "user@example.com"
      #     reply_to "other.user@example.com"
      #   end
      #
      # @example Hardcoded value (Array)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer
      #     include Hanami::Mailer
      #
      #     to ["user-1@example.com", "user-2@example.com"]
      #     reply_to ["other.user-1@example.com", "other.user-2@example.com"]
      #   end
      #
      # @example Method (Symbol)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer
      #     include Hanami::Mailer
      #     to "user@example.com"
      #     reply_to :email_address
      #
      #     private
      #
      #     def email_address
      #       user.email
      #     end
      #   end
      #
      #   other_user = User.new(name: 'L')
      #   WelcomeMailer.deliver(user: other_user)
      #
      # @example Method that returns a collection of recipients
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer
      #     include Hanami::Mailer
      #     to "user@example.com"
      #     reply_to :recipients
      #
      #     private
      #
      #     def recipients
      #       users.map(&:email)
      #     end
      #   end
      #
      #   other_users = [User.new(name: 'L'), User.new(name: 'MG')]
      #   WelcomeMailer.deliver(users: other_users)
      def reply_to(value = nil)
        if value.nil?
          @reply_to
        else
          @reply_to = value
        end
      end

      # Sets the MAIL FROM address for mail messages.
      # This lets you specify a "bounce address" different from the sender
      # address specified with `from`.
      #
      # It accepts a hardcoded value as a string, or a symbol that represents
      # an instance method for more complex logic.
      #
      # This value is optional.
      #
      # When a value is given, specify the MAIL FROM address of the email
      # Otherwise, it returns the MAIL FROM address of the email
      #
      # This is part of a DSL, for this reason when this method is called with
      # an argument, it will set the corresponding class variable. When
      # called without, it will return the already set value, or the default.
      #
      # @overload return_path(value)
      #   Sets the MAIL FROM address
      #   @param value [String, Symbol] the hardcoded value or method name
      #   @return [NilClass]
      #
      # @overload return_path
      #   Returns the MAIL FROM address
      #   @return [String, Symbol] the MAIL FROM address
      #
      # @since 1.3.2
      #
      # @example Hardcoded value (String)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer
      #     include Hanami::Mailer
      #
      #     return_path "bounce@example.com"
      #   end
      #
      # @example Method (Symbol)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer
      #     include Hanami::Mailer
      #     return_path :bounce_address
      #
      #     private
      #
      #     def bounce_address
      #       "bounce@example.com"
      #     end
      #   end
      def return_path(value = nil)
        if value.nil?
          @return_path
        else
          @return_path = value
        end
      end

      # Sets the subject for mail messages
      #
      # It accepts a hardcoded value as a string, or a symbol that represents
      # an instance method for more complex logic.
      #
      # This value MUST be set, otherwise an exception is raised at the delivery
      # time.
      #
      # This is part of a DSL, for this reason when this method is called with
      # an argument, it will set the corresponding class variable. When
      # called without, it will return the already set value, or the default.
      #
      # @overload subject(value)
      #   Sets the subject
      #   @param value [String, Symbol] the hardcoded value or method name
      #   @return [NilClass]
      #
      # @overload subject
      #   Returns the subject
      #   @return [String, Symbol] the subject
      #
      # @since 0.1.0
      #
      # @example Hardcoded value (String)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     subject "Welcome"
      #   end
      #
      # @example Lazy value (Proc)
      #   require 'hanami/mailer'
      #
      #   class WelcomeMailer < Hanami::Mailer
      #     subject ->(locals) { "Hello #{locals.fetch(:user).name}" }
      #   end
      #
      #   user = User.new(name: 'L')
      #   WelcomeMailer.new(configuration: configuration).deliver(user: user)
      def subject(value = nil)
        if value.nil?
          @subject
        else
          @subject = value
        end
      end

      # Set the template name **IF** it differs from the naming convention.
      #
      # For a given mailer named `Signup::Welcome` it will look for
      # `signup/welcome.*.*` templates under the root directory.
      #
      # If for some reason, we need to specify a different template name, we can
      # use this method.
      #
      # @param value [String] the template name
      #
      # @since 0.1.0
      # @api unstable
      #
      # @example Custom template name
      #   require 'hanami/mailer'
      #
      #   class MyMailer < Hanami::Mailer
      #     template 'mailer'
      #   end
      def template(value)
        @template = value
      end

      # @since next
      # @api unstable
      def template_name
        @template || name
      end

      # Set the layout name to use
      #
      # If you need several mailers to share the same global layout,
      # use this method to define the file to render.
      #
      # The layout file must then use <%= yield %> to include the mailer specific content.
      # Default behaviour if nothing is provided is to use the template directly, without any layout.
      #
      # For a layout named `default_mailer`, it will look for
      # `default_mailer.*.*` files under the root directory.
      #
      # @param value [String] the layout name
      #
      # @since 2.0.0
      # @api unstable
      #
      # @example Custom layout name
      #   require 'hanami/mailer'
      #
      #   class MyMailer < Hanami::Mailer
      #     layout 'mailer_layout'
      #   end
      def layout(value)
        @layout = value
      end

      def layout_name
        @layout
      end

      # Before callback for email delivery
      #
      # @since next
      # @api unstable
      #
      # @example
      #   require 'hanami/mailer'
      #
      #   module Billing
      #     class InvoiceMailer < Hanami::Mailer
      #       subject 'Invoice'
      #       from    'noreply@example.com'
      #       to      ->(locals) { locals.fetch(:user).email }
      #
      #       before do |mail, locals|
      #         user = locals.fetch(:user)
      #         mail.attachments["invoice-#{invoice_code}-#{user.id}.pdf"] = File.read('/path/to/invoice.pdf')
      #       end
      #
      #       def invoice_code
      #         "123"
      #       end
      #     end
      #   end
      #
      #   invoice = Invoice.new
      #   user    = User.new(name: 'L', email: 'user@example.com')
      #
      #   InvoiceMailer.new(configuration: configuration).deliver(invoice: invoice, user: user)
      def before(&blk)
        if block_given?
          @before = blk
        else
          @before
        end
      end
    end
  end
end
