# frozen_string_literal: true

RSpec.describe Hanami::Mailer::Message do
  describe "#initialize" do
    describe "address normalization" do
      it "wraps a string address in an array" do
        message = described_class.new(
          from: "sender@example.com",
          to: "recipient@example.com",
          subject: "Test"
        )

        expect(message.from).to eq(["sender@example.com"])
        expect(message.to).to eq(["recipient@example.com"])
      end

      it "passes an array through unchanged" do
        message = described_class.new(
          from: "sender@example.com",
          to: ["a@example.com", "b@example.com"],
          subject: "Test"
        )

        expect(message.to).to eq(["a@example.com", "b@example.com"])
      end

      it "normalizes all address fields" do
        message = described_class.new(
          from: "sender@example.com",
          to: "to@example.com",
          cc: "cc@example.com",
          bcc: "bcc@example.com",
          reply_to: "reply@example.com",
          return_path: "bounces@example.com",
          subject: "Test"
        )

        expect(message.cc).to eq(["cc@example.com"])
        expect(message.bcc).to eq(["bcc@example.com"])
        expect(message.reply_to).to eq(["reply@example.com"])
        expect(message.return_path).to eq(["bounces@example.com"])
      end

      it "stores nil address fields as nil" do
        message = described_class.new(
          from: "sender@example.com",
          to: "to@example.com",
          subject: "Test"
        )

        expect(message.cc).to be_nil
        expect(message.bcc).to be_nil
        expect(message.reply_to).to be_nil
        expect(message.return_path).to be_nil
      end
    end

    describe "defaults" do
      subject(:message) do
        described_class.new(from: "from@example.com", to: "to@example.com", subject: "Test")
      end

      it "defaults charset to UTF-8" do
        expect(message.charset).to eq("UTF-8")
      end

      it "defaults html_body to nil" do
        expect(message.html_body).to be_nil
      end

      it "defaults text_body to nil" do
        expect(message.text_body).to be_nil
      end

      it "defaults attachments to an empty array" do
        expect(message.attachments).to eq([])
      end

      it "defaults headers to an empty hash" do
        expect(message.headers).to eq({})
      end

      it "defaults delivery_options to an empty hash" do
        expect(message.delivery_options).to eq({})
      end
    end

    describe "body storage" do
      it "stores html_body" do
        message = described_class.new(
          from: "from@example.com",
          to: "to@example.com",
          subject: "Test",
          html_body: "<p>Hello</p>"
        )

        expect(message.html_body).to eq("<p>Hello</p>")
      end

      it "stores text_body" do
        message = described_class.new(
          from: "from@example.com",
          to: "to@example.com",
          subject: "Test",
          text_body: "Hello"
        )

        expect(message.text_body).to eq("Hello")
      end
    end

    describe "recipient validation" do
      it "raises MissingRecipientError when to, cc, and bcc are all nil" do
        expect {
          described_class.new(from: "from@example.com", subject: "Test")
        }.to raise_error(Hanami::Mailer::MissingRecipientError)
      end

      it "raises MissingRecipientError when to is an empty array" do
        expect {
          described_class.new(from: "from@example.com", to: [], subject: "Test")
        }.to raise_error(Hanami::Mailer::MissingRecipientError)
      end

      it "is valid with only a cc address" do
        expect {
          described_class.new(from: "from@example.com", cc: "cc@example.com", subject: "Test")
        }.not_to raise_error
      end

      it "is valid with only a bcc address" do
        expect {
          described_class.new(from: "from@example.com", bcc: "bcc@example.com", subject: "Test")
        }.not_to raise_error
      end
    end
  end

  describe "#to_h" do
    it "includes all message fields" do
      message = described_class.new(
        from: "from@example.com",
        to: "to@example.com",
        cc: "cc@example.com",
        subject: "Test",
        html_body: "<p>Hello</p>",
        text_body: "Hello",
        headers: {"X-Custom" => "value"},
        delivery_options: {track_opens: true}
      )

      hash = message.to_h

      expect(hash[:from]).to eq(["from@example.com"])
      expect(hash[:to]).to eq(["to@example.com"])
      expect(hash[:cc]).to eq(["cc@example.com"])
      expect(hash[:subject]).to eq("Test")
      expect(hash[:html_body]).to eq("<p>Hello</p>")
      expect(hash[:text_body]).to eq("Hello")
      expect(hash[:charset]).to eq("UTF-8")
      expect(hash[:headers]).to eq({"X-Custom" => "value"})
      expect(hash[:delivery_options]).to eq({track_opens: true})
    end

    it "includes nil fields" do
      message = described_class.new(
        from: "from@example.com",
        to: "to@example.com",
        subject: "Test"
      )

      hash = message.to_h

      expect(hash).to have_key(:cc)
      expect(hash[:cc]).to be_nil
      expect(hash).to have_key(:bcc)
      expect(hash[:bcc]).to be_nil
      expect(hash[:html_body]).to be_nil
      expect(hash[:text_body]).to be_nil
    end
  end
end
