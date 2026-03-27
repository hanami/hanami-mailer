# frozen_string_literal: true

RSpec.describe Hanami::Mailer, "basic delivery" do
  before do
    Hanami::Mailer::Delivery::Test.clear
  end

  describe "simple mailer with static values" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Welcome to our app"
      end
    end

    it "delivers email with static metadata" do
      mailer = mailer_class.new
      result = mailer.deliver

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
      expect(result.message.from).to eq(["noreply@example.com"])
      expect(result.message.to).to eq(["user@example.com"])
      expect(result.message.subject).to eq("Welcome to our app")
    end

    it "stores delivered mail in test delivery" do
      mailer = mailer_class.new
      mailer.deliver

      expect(Hanami::Mailer::Delivery::Test.deliveries.size).to eq(1)
      result = Hanami::Mailer::Delivery::Test.deliveries.first
      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.message.subject).to eq("Welcome to our app")
    end
  end

  describe "mailer with dynamic values" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to { |user:| user[:email] }
        subject { |user:| "Welcome, #{user[:name]}!" }

        expose :user
      end
    end

    it "evaluates procs with locals" do
      mailer = mailer_class.new
      user = {name: "Alice", email: "alice@example.com"}

      result = mailer.deliver(user: user)

      expect(result.message.to).to eq(["alice@example.com"])
      expect(result.message.subject).to eq("Welcome, Alice!")
    end
  end

  describe "mailer with multiple recipients" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to ["user1@example.com", "user2@example.com"]
        cc "manager@example.com"
        bcc "admin@example.com"
        subject "Team notification"
      end
    end

    it "delivers to multiple recipients" do
      mailer = mailer_class.new
      result = mailer.deliver

      expect(result.message.to).to eq(["user1@example.com", "user2@example.com"])
      expect(result.message.cc).to eq(["manager@example.com"])
      expect(result.message.bcc).to eq(["admin@example.com"])
    end
  end

  describe "mailer with exposures" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to { |user:| user[:email] }
        subject "Your order confirmation"

        expose :user
        expose :order
        expose :total do |order:|
          order[:items].sum { |item| item[:price] }
        end
      end
    end

    it "evaluates exposures" do
      mailer = mailer_class.new
      user = {name: "Bob", email: "bob@example.com"}
      order = {id: 123, items: [{price: 10}, {price: 20}]}

      message = mailer.prepare(user: user, order: order)

      expect(message).to be_a(Hanami::Mailer::Message)
      expect(message.to).to eq(["bob@example.com"])
    end
  end

  describe "mailer with metadata using keyword arguments" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to { |user_email:| user_email }
        subject { |user_name:| "Welcome, #{user_name}!" }

        expose :user_name do |user:|
          user[:name]
        end

        expose :user_email do |user:|
          user[:email]
        end

        expose :user
      end
    end

    it "evaluates metadata with keyword arguments from exposures" do
      mailer = mailer_class.new
      user = {name: "Charlie", email: "charlie@example.com"}

      result = mailer.deliver(user: user)

      expect(result.message.to).to eq(["charlie@example.com"])
      expect(result.message.subject).to eq("Welcome, Charlie!")
    end
  end

  describe "mailer with metadata dependencies on exposures" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to { |recipient_email:| recipient_email }
        subject { |greeting:, recipient_name:| "#{greeting}, #{recipient_name}!" }

        expose :user
        expose :recipient_name do |user:|
          user[:name]
        end

        expose :recipient_email do |user:|
          user[:email]
        end

        expose :greeting do |user:|
          user[:vip] ? "Greetings" : "Hello"
        end
      end
    end

    it "evaluates metadata with dependencies on exposures" do
      mailer = mailer_class.new
      user = {name: "Diana", email: "diana@example.com", vip: true}

      result = mailer.deliver(user: user)

      expect(result.message.to).to eq(["diana@example.com"])
      expect(result.message.subject).to eq("Greetings, Diana!")
    end

    it "works with non-vip users" do
      mailer = mailer_class.new
      user = {name: "Eve", email: "eve@example.com", vip: false}

      result = mailer.deliver(user: user)

      expect(result.message.to).to eq(["eve@example.com"])
      expect(result.message.subject).to eq("Hello, Eve!")
    end
  end

  describe "error handling" do
    describe "missing recipient" do
      let(:mailer_class) do
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          subject "Test"
        end
      end

      it "raises error when no recipients are provided" do
        mailer = mailer_class.new
        expect { mailer.deliver }.to raise_error(Hanami::Mailer::MissingRecipientError)
      end
    end
  end

  describe "charset configuration" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "こんにちは"
      end
    end

    it "uses UTF-8 by default" do
      mailer = mailer_class.new
      result = mailer.deliver

      expect(result.message.charset).to eq("UTF-8")
    end
  end

  describe "reply_to" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        reply_to "support@example.com"
        subject "Support ticket"
      end
    end

    it "sets reply_to address" do
      mailer = mailer_class.new
      result = mailer.deliver

      expect(result.message.reply_to).to eq(["support@example.com"])
    end
  end
end
