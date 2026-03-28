# frozen_string_literal: true

RSpec.describe "Delivery results" do
  let(:mailer) { mailer_class.new }

  let(:mailer_class) do
    Class.new(Hanami::Mailer) do
      from "noreply@example.com"
      to "user@example.com"
      subject "Test email"
    end
  end

  describe "Delivery::Result" do
    it "returns a Result object from deliver" do
      result = mailer.deliver

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
    end

    it "includes the prepared message" do
      result = mailer.deliver

      expect(result.message).to be_a(Hanami::Mailer::Message)
      expect(result.message.from).to eq(["noreply@example.com"])
      expect(result.message.to).to eq(["user@example.com"])
      expect(result.message.subject).to eq("Test email")
    end

    it "indicates success" do
      result = mailer.deliver

      expect(result.success?).to be true
    end

    it "has nil error on success" do
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
      user = {name: "Alice", email: "alice@example.com"}
      result = mailer.deliver(user: user)

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
      expect(result.error).to be_nil
    end

    it "stores Result objects in deliveries" do
      user = {name: "Bob", email: "bob@example.com"}
      mailer.deliver(user: user)

      expect(Hanami::Mailer::Delivery::Test.deliveries.size).to eq(1)
      result = Hanami::Mailer::Delivery::Test.deliveries.first
      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.message.to).to eq(["bob@example.com"])
    end

    it "has nil response for test delivery" do
      user = {name: "Charlie", email: "charlie@example.com"}
      result = mailer.deliver(user: user)

      expect(result.response).to be_nil
    end

    it "allows inspecting all delivered messages via results" do
      mailer.deliver(user: {name: "Alice", email: "alice@example.com"})
      mailer.deliver(user: {name: "Bob", email: "bob@example.com"})
      mailer.deliver(user: {name: "Charlie", email: "charlie@example.com"})

      messages = Hanami::Mailer::Delivery::Test.deliveries.map(&:message)
      expect(messages.map { |m| m.to.first }).to eq([
        "alice@example.com",
        "bob@example.com",
        "charlie@example.com"
      ])
    end
  end

  describe "custom delivery method with extended result" do
    let(:mailer) { mailer_class.new(delivery_method:) }

    let(:delivery_method) {
      result_class = self.result_class

      Class.new {
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
      }.new
    }

    let(:result_class) {
      Class.new(Hanami::Mailer::Delivery::Result) do
        attr_reader :message_id, :submitted_at

        def initialize(message_id:, submitted_at: nil, **)
          super(**)
          @message_id = message_id
          @submitted_at = submitted_at
        end
      end
    }

    it "allows delivery methods to return custom Result subclasses" do
      result = mailer.deliver

      expect(result).to be_a(result_class)
      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
    end

    it "provides access to custom attributes" do
      result = mailer.deliver

      expect(result.message_id).to match(/^msg_[a-f0-9]{16}$/)
      expect(result.submitted_at).to be_a(Time)
      expect(result.response).to eq({id: result.message_id, status: "queued"})
    end

    it "still provides standard Result interface" do
      result = mailer.deliver

      expect(result.message).to be_a(Hanami::Mailer::Message)
      expect(result.message.subject).to eq("Test email")
      expect(result.success?).to be true
      expect(result.error).to be_nil
    end
  end

  describe "custom delivery method with failure result" do
    let(:mailer) { mailer_class.new(delivery_method:) }

    let(:delivery_method) {
      result_class = self.result_class

      Class.new {
        define_method(:call) do |message|
          error = StandardError.new("API rate limit exceeded")

          result_class.new(
            message: message,
            success: false,
            error: error,
            error_code: 429
          )
        end
      }.new
    }

    let(:result_class) {
      Class.new(Hanami::Mailer::Delivery::Result) do
        attr_reader :error_code

        def initialize(error_code:, **)
          super(**)
          @error_code = error_code
        end
      end
    }

    it "returns custom result with failure information" do
      result = mailer.deliver

      expect(result).to be_a(result_class)
      expect(result.success?).to be false
      expect(result.error).to be_a(StandardError)
      expect(result.error.message).to eq("API rate limit exceeded")
      expect(result.error_code).to eq(429)
    end
  end
end
