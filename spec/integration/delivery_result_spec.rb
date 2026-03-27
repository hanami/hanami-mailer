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

  describe "custom delivery method with extended result" do
    let(:custom_result_class) do
      Class.new(Hanami::Mailer::Delivery::Result) do
        attr_reader :message_id, :submitted_at

        def initialize(message_id:, submitted_at: nil, **)
          super(**)
          @message_id = message_id
          @submitted_at = submitted_at
        end
      end
    end

    let(:custom_delivery) do
      result_class = custom_result_class

      Class.new do
        define_method(:call) do |message|
          message_id = "msg_#{SecureRandom.hex(8)}"
          submitted_at = Time.now

          result_class.new(
            message: message,
            message_id: message_id,
            submitted_at: submitted_at,
            response: {id: message_id, status: "queued"}
          )
        end
      end.new
    end

    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Custom delivery test"
      end
    end

    it "allows delivery methods to return custom Result subclasses" do
      mailer = mailer_class.new(delivery: custom_delivery)
      result = mailer.deliver

      expect(result).to be_a(custom_result_class)
      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
    end

    it "provides access to custom attributes" do
      mailer = mailer_class.new(delivery: custom_delivery)
      result = mailer.deliver

      expect(result.message_id).to match(/^msg_[a-f0-9]{16}$/)
      expect(result.submitted_at).to be_a(Time)
      expect(result.response).to eq({id: result.message_id, status: "queued"})
    end

    it "still provides standard Result interface" do
      mailer = mailer_class.new(delivery: custom_delivery)
      result = mailer.deliver

      expect(result.message).to be_a(Hanami::Mailer::Message)
      expect(result.message.subject).to eq("Custom delivery test")
      expect(result.success?).to be true
      expect(result.error).to be_nil
    end
  end

  describe "custom delivery method with failure result" do
    let(:failing_result_class) do
      Class.new(Hanami::Mailer::Delivery::Result) do
        attr_reader :error_code

        def initialize(error_code:, **)
          super(**)
          @error_code = error_code
        end
      end
    end

    let(:failing_delivery) do
      result_class = failing_result_class

      Class.new do
        define_method(:call) do |message|
          error = StandardError.new("API rate limit exceeded")

          result_class.new(
            message: message,
            success: false,
            error: error,
            error_code: 429
          )
        end
      end.new
    end

    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Failing delivery test"
      end
    end

    it "returns custom result with failure information" do
      mailer = mailer_class.new(delivery: failing_delivery)
      result = mailer.deliver

      expect(result).to be_a(failing_result_class)
      expect(result.success?).to be false
      expect(result.error).to be_a(StandardError)
      expect(result.error.message).to eq("API rate limit exceeded")
      expect(result.error_code).to eq(429)
    end
  end
end
