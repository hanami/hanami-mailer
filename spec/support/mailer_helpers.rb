# frozen_string_literal: true

module MailerSpecHelpers
  # Build a minimal valid Message for use in unit tests.
  # Accepts keyword arguments to override any default field.
  #
  # @example
  #   let(:message) { minimal_message }
  #   let(:message) { minimal_message(subject: "Hello") }
  def minimal_message(**attrs)
    Hanami::Mailer::Message.new(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      **attrs
    )
  end
end

RSpec.configure do |config|
  config.include MailerSpecHelpers
end
