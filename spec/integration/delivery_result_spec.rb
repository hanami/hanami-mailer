# frozen_string_literal: true

RSpec.describe Hanami::Mailer, "delivery results" do
  describe "Delivery::Result" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test email"
      end
    end

    it "returns a Result object from deliver" do
      mailer = mailer_class.new
      result = mailer.deliver

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
    end

    it "includes the prepared message" do
      mailer = mailer_class.new
      result = mailer.deliver

      expect(result.message).to be_a(Hanami::Mailer::Message)
      expect(result.message.from).to eq(["noreply@example.com"])
      expect(result.message.to).to eq(["user@example.com"])
      expect(result.message.subject).to eq("Test email")
    end

    it "indicates success" do
      mailer = mailer_class.new
      result = mailer.deliver

      expect(result.success?).to be true
    end

    it "has nil error on success" do
      mailer = mailer_class.new
      result = mailer.deliver

      expect(result.error).to be_nil
    end
  end

  describe "Test delivery" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to { |user:| user[:email] }
        subject { |user:| "Welcome, #{user[:name]}!" }

        expose :user
      end
    end

    it "returns a successful Result" do
      mailer = mailer_class.new
      user = {name: "Alice", email: "alice@example.com"}
      result = mailer.deliver(user: user)

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
      expect(result.error).to be_nil
    end

    it "stores Result objects in deliveries" do
      mailer = mailer_class.new
      user = {name: "Bob", email: "bob@example.com"}
      mailer.deliver(user: user)

      expect(Hanami::Mailer::Delivery::Test.deliveries.size).to eq(1)
      result = Hanami::Mailer::Delivery::Test.deliveries.first
      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.message.to).to eq(["bob@example.com"])
    end

    it "has nil response for test delivery" do
      mailer = mailer_class.new
      user = {name: "Charlie", email: "charlie@example.com"}
      result = mailer.deliver(user: user)

      expect(result.response).to be_nil
    end

    it "allows inspecting all delivered messages via results" do
      mailer = mailer_class.new

      mailer.deliver(user: {name: "Alice", email: "alice@example.com"})
      mailer.deliver(user: {name: "Bob", email: "bob@example.com"})
      mailer.deliver(user: {name: "Charlie", email: "charlie@example.com"})

      results = Hanami::Mailer::Delivery::Test.deliveries
      expect(results.size).to eq(3)

      messages = results.map(&:message)
      expect(messages.map { |m| m.to.first }).to eq([
        "alice@example.com",
        "bob@example.com",
        "charlie@example.com"
      ])
    end
  end

  describe "SMTP delivery" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "SMTP test"
      end
    end

    it "returns a Result on successful delivery", :smtp do
      smtp_delivery = Hanami::Mailer::Delivery::SMTP.new(
        address: "smtp.example.com",
        port: 587
      )

      mailer = mailer_class.new(delivery: smtp_delivery)

      # Mock successful SMTP delivery
      mail_double = instance_double("Mail::Message")
      allow(mail_double).to receive(:delivery_method)
      allow(mail_double).to receive(:deliver!)
      allow_any_instance_of(Hanami::Mailer::Delivery::SMTP)
        .to receive(:to_mail).and_return(mail_double)

      result = mailer.deliver

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
      expect(result.error).to be_nil
      expect(result.response).to eq(mail_double)
    end

    it "returns a Result with error on SMTP failure", :smtp do
      smtp_delivery = Hanami::Mailer::Delivery::SMTP.new(
        address: "smtp.example.com",
        port: 587
      )

      mailer = mailer_class.new(delivery: smtp_delivery)

      # Mock SMTP error
      smtp_error = Net::SMTPFatalError.new("550 Mailbox unavailable")
      mail_double = instance_double("Mail::Message")
      allow(mail_double).to receive(:delivery_method)
      allow(mail_double).to receive(:deliver!).and_raise(smtp_error)
      allow_any_instance_of(Hanami::Mailer::Delivery::SMTP)
        .to receive(:to_mail).and_return(mail_double)

      result = mailer.deliver

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be false
      expect(result.error).to eq(smtp_error)
      expect(result.error.message).to include("550 Mailbox unavailable")
    end

    it "includes the message even when delivery fails", :smtp do
      smtp_delivery = Hanami::Mailer::Delivery::SMTP.new(
        address: "smtp.example.com",
        port: 587
      )

      mailer = mailer_class.new(delivery: smtp_delivery)

      # Mock SMTP error
      smtp_error = Net::SMTPAuthenticationError.new("Authentication failed")
      mail_double = instance_double("Mail::Message")
      allow(mail_double).to receive(:delivery_method)
      allow(mail_double).to receive(:deliver!).and_raise(smtp_error)
      allow_any_instance_of(Hanami::Mailer::Delivery::SMTP)
        .to receive(:to_mail).and_return(mail_double)

      result = mailer.deliver

      expect(result.message).to be_a(Hanami::Mailer::Message)
      expect(result.message.subject).to eq("SMTP test")
    end
  end

  describe "custom delivery method with extended result" do
    # Simulates a third-party delivery service like Postmark or Mailchimp
    class CustomResult < Hanami::Mailer::Delivery::Result
      attr_reader :message_id, :submitted_at

      def initialize(message_id:, submitted_at: nil, **)
        super(**)
        @message_id = message_id
        @submitted_at = submitted_at
      end
    end

    class CustomDelivery
      def call(message)
        # Simulate API call
        message_id = "msg_#{SecureRandom.hex(8)}"
        submitted_at = Time.now

        CustomResult.new(
          message: message,
          message_id: message_id,
          submitted_at: submitted_at,
          response: {id: message_id, status: "queued"}
        )
      end
    end

    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Custom delivery test"
      end
    end

    it "allows delivery methods to return custom Result subclasses" do
      custom_delivery = CustomDelivery.new
      mailer = mailer_class.new(delivery: custom_delivery)

      result = mailer.deliver

      expect(result).to be_a(CustomResult)
      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
    end

    it "provides access to custom attributes" do
      custom_delivery = CustomDelivery.new
      mailer = mailer_class.new(delivery: custom_delivery)

      result = mailer.deliver

      expect(result.message_id).to match(/^msg_[a-f0-9]{16}$/)
      expect(result.submitted_at).to be_a(Time)
      expect(result.response).to eq({id: result.message_id, status: "queued"})
    end

    it "still provides standard Result interface" do
      custom_delivery = CustomDelivery.new
      mailer = mailer_class.new(delivery: custom_delivery)

      result = mailer.deliver

      expect(result.message).to be_a(Hanami::Mailer::Message)
      expect(result.message.subject).to eq("Custom delivery test")
      expect(result.success?).to be true
      expect(result.error).to be_nil
    end
  end

  describe "custom delivery method with failure result" do
    class FailingCustomResult < Hanami::Mailer::Delivery::Result
      attr_reader :error_code

      def initialize(error_code:, **)
        super(**)
        @error_code = error_code
      end
    end

    class FailingCustomDelivery
      def call(message)
        error = StandardError.new("API rate limit exceeded")

        FailingCustomResult.new(
          message: message,
          success: false,
          error: error,
          error_code: 429
        )
      end
    end

    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Failing delivery test"
      end
    end

    it "returns custom result with failure information" do
      failing_delivery = FailingCustomDelivery.new
      mailer = mailer_class.new(delivery: failing_delivery)

      result = mailer.deliver

      expect(result).to be_a(FailingCustomResult)
      expect(result.success?).to be false
      expect(result.error).to be_a(StandardError)
      expect(result.error.message).to eq("API rate limit exceeded")
      expect(result.error_code).to eq(429)
    end
  end

  describe "result usage patterns" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to { |user:| user[:email] }
        subject "Notification"

        expose :user
      end
    end

    it "allows conditional logic based on success" do
      mailer = mailer_class.new
      user = {name: "Alice", email: "alice@example.com"}

      result = mailer.deliver(user: user)

      if result.success?
        expect(result.message.to).to eq(["alice@example.com"])
      else
        raise "Expected delivery to succeed"
      end
    end

    it "provides message for logging on success" do
      mailer = mailer_class.new
      user = {name: "Bob", email: "bob@example.com"}

      result = mailer.deliver(user: user)

      log_message = "Delivered to #{result.message.to.join(', ')} with subject '#{result.message.subject}'"
      expect(log_message).to eq("Delivered to bob@example.com with subject 'Notification'")
    end

    it "provides error details for logging on failure" do
      # Create a custom delivery that fails
      failing_delivery = Class.new do
        def call(message)
          Hanami::Mailer::Delivery::Result.new(
            message: message,
            success: false,
            error: StandardError.new("Network timeout")
          )
        end
      end.new

      mailer = mailer_class.new(delivery: failing_delivery)
      user = {name: "Charlie", email: "charlie@example.com"}

      result = mailer.deliver(user: user)

      if result.success?
        raise "Expected delivery to fail"
      else
        log_message = "Failed to deliver to #{result.message.to.join(', ')}: #{result.error.message}"
        expect(log_message).to eq("Failed to deliver to charlie@example.com: Network timeout")
      end
    end
  end
end
