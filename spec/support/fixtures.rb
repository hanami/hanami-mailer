# frozen_string_literal: true

class InvoiceMailer < Hanami::Mailer
  template "invoice"
end

class RenderMailer < Hanami::Mailer
end

class TemplateEngineMailer < Hanami::Mailer
end

class CharsetMailer < Hanami::Mailer
  from    "noreply@example.com"
  to      "user@example.com"
  subject "こんにちは"
end

class MissingFromMailer < Hanami::Mailer
  template "missing"

  to      "recipient@example.com"
  subject "Hello"
end

class MissingToMailer < Hanami::Mailer
  template "missing"

  from    "sender@example.com"
  subject "Hello"
end

class CcOnlyMailer < Hanami::Mailer
  template "missing"

  cc      "recipient@example.com"
  from    "sender@example.com"
  subject "Hello"
end

class BccOnlyMailer < Hanami::Mailer
  template "missing"

  bcc      "recipient@example.com"
  from    "sender@example.com"
  subject "Hello"
end

User = Struct.new(:name, :email)

class LazyMailer < Hanami::Mailer
end

class ProcMailer < Hanami::Mailer
  from    ->(locals) { "hello-#{locals.fetch(:user).name.downcase}@example.com" }
  to      ->(locals) { locals.fetch(:user).email }
  subject ->(locals) { "[Hanami] #{locals.fetch(:greeting)}" }

  before do |_, locals|
    locals[:greeting] = "Hello, #{locals.fetch(:user).name}"
  end
end

class WelcomeMailer < Hanami::Mailer
  from        "noreply@sender.com"
  to          ["noreply@recipient.com", "owner@recipient.com"]
  cc          "cc@recipient.com"
  bcc         "bcc@recipient.com"
  reply_to    "reply_to@recipient.com"
  return_path "bounce@sender.com"

  subject "Welcome"

  before do |mail|
    mail.attachments["invoice.pdf"] = "/path/to/invoice-#{invoice_code}.pdf"
  end

  def greeting
    "Ahoy"
  end

  def invoice_code
    "123"
  end
end

class WithLayoutMailer < Hanami::Mailer
  from        "noreply@sender.com"
  to          "owner@recipient.com"

  subject "Mail with layout"

  layout "layout"
end

class EventMailer < Hanami::Mailer
  from    "events@domain.test"
  to      ->(locals) { locals.fetch(:user).email }
  subject ->(locals) { "Invitation: #{locals.fetch(:event).title}" }

  before do |mail, locals|
    mail.attachments["invitation-#{locals.fetch(:event).id}.ics"] = generate_invitation_attachment(locals)
  end

  private

  # Simulate on-the-fly creation of an attachment file.
  # For speed purposes we're not gonna create the file, but only return a path.
  def generate_invitation_attachment(locals)
    "invitation-#{locals.fetch(:event).id}.ics"
  end
end

class MandrillDeliveryMethod
  def initialize(options)
    @options = options
  end

  def deliver!(mail)
    @options.fetch(:deliveries).push(mail)
  end
end

module Users
  class Welcome < Hanami::Mailer
  end
end

module Web
  module Mailers
    class SignupMailer < Hanami::Mailer
    end
  end
end

module DefaultSubject
  def self.included(mailer)
    mailer.subject "default subject"
  end
end
