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

    context "when the message has both bodies and an attachment" do
      let(:message) do
        Hanami::Mailer::Message.new(
          from: "noreply@example.com",
          to: "user@example.com",
          subject: "SMTP test",
          html_body: "<h1>Hi</h1>",
          text_body: "Hi",
          attachments: [
            Hanami::Mailer::Attachment.new(
              filename: "invoice.pdf",
              content: "%PDF-1.4 fake",
              content_type: "application/pdf"
            )
          ]
        )
      end

      let(:mail) { smtp_delivery.call(message).response }

      it "nests the bodies in a multipart/alternative under multipart/mixed" do
        expect(mail.mime_type).to eq("multipart/mixed")

        alternative = mail.parts.find { |part| part.mime_type == "multipart/alternative" }
        expect(alternative).not_to be_nil
        expect(alternative.parts.map(&:mime_type)).to contain_exactly("text/plain", "text/html")
      end

      it "keeps the attachment as a sibling of the multipart/alternative" do
        expect(mail.parts.map(&:mime_type)).to contain_exactly("multipart/alternative", "application/pdf")
        expect(mail.attachments.map(&:filename)).to eq(["invoice.pdf"])
      end
    end
  end
end
