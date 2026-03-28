# frozen_string_literal: true

require "mail"
require "net/smtp"

RSpec.describe Hanami::Mailer::Delivery::SMTP do
  subject(:smtp_delivery) { described_class.new(address: "smtp.example.com", port: 587) }

  let(:mailer_class) do
    Class.new(Hanami::Mailer) do
      from "noreply@example.com"
      to "user@example.com"
      subject "SMTP test"
    end
  end

  let(:mailer) { mailer_class.new(delivery_method: smtp_delivery) }

  before do
    # Prevent actual SMTP connections across all examples
    allow_any_instance_of(Mail::Message).to receive(:delivery_method)
    allow_any_instance_of(Mail::Message).to receive(:deliver!).and_return(nil)
  end

  describe "#call" do
    it "returns a successful Result when delivery succeeds" do
      result = mailer.deliver

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
      expect(result.error).to be_nil
    end

    it "includes a Mail::Message as the response" do
      result = mailer.deliver

      expect(result.response).to be_a(Mail::Message)
    end

    it "includes the prepared message in the result" do
      result = mailer.deliver

      expect(result.message).to be_a(Hanami::Mailer::Message)
      expect(result.message.subject).to eq("SMTP test")
    end

    context "when Net::SMTPFatalError is raised" do
      let(:smtp_error) { Net::SMTPFatalError.new("550 Mailbox unavailable") }

      before do
        allow_any_instance_of(Mail::Message).to receive(:deliver!).and_raise(smtp_error)
      end

      it "returns a failed Result" do
        result = mailer.deliver

        expect(result.success?).to be false
        expect(result.error).to eq(smtp_error)
      end

      it "still includes the prepared message" do
        result = mailer.deliver

        expect(result.message).to be_a(Hanami::Mailer::Message)
        expect(result.message.subject).to eq("SMTP test")
      end
    end

    context "when Net::SMTPAuthenticationError is raised" do
      before do
        allow_any_instance_of(Mail::Message).to receive(:deliver!)
          .and_raise(Net::SMTPAuthenticationError.new("Authentication failed"))
      end

      it "returns a failed Result with the authentication error" do
        result = mailer.deliver

        expect(result.success?).to be false
        expect(result.error.message).to include("Authentication failed")
      end
    end
  end
end
