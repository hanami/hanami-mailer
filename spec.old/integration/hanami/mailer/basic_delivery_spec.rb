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
      mail = mailer.deliver

      expect(mail).to be_a(Mail::Message)
      expect(mail.from).to eq(["noreply@example.com"])
      expect(mail.to).to eq(["user@example.com"])
      expect(mail.subject).to eq("Welcome to our app")
    end

    it "stores delivered mail in test delivery" do
      mailer = mailer_class.new
      mailer.deliver

      expect(Hanami::Mailer::Delivery::Test.deliveries.size).to eq(1)
      mail = Hanami::Mailer::Delivery::Test.deliveries.first
      expect(mail.subject).to eq("Welcome to our app")
    end
  end

  describe "mailer with dynamic values" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to { |locals| locals[:user][:email] }
        subject { |locals| "Welcome, #{locals[:user][:name]}!" }

        expose :user
      end
    end

    it "evaluates procs with locals" do
      mailer = mailer_class.new
      user = {name: "Alice", email: "alice@example.com"}

      mail = mailer.deliver(user: user)

      expect(mail.to).to eq(["alice@example.com"])
      expect(mail.subject).to eq("Welcome, Alice!")
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
      mail = mailer.deliver

      expect(mail.to).to eq(["user1@example.com", "user2@example.com"])
      expect(mail.cc).to eq(["manager@example.com"])
      expect(mail.bcc).to eq(["admin@example.com"])
    end
  end

  describe "mailer with exposures" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to { |locals| locals[:user][:email] }
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

  describe "error handling" do
    describe "missing from address" do
      let(:mailer_class) do
        Class.new(Hanami::Mailer) do
          to "user@example.com"
          subject "Test"
        end
      end

      it "raises error when from is not provided and no default is set" do
        mailer = mailer_class.new
        expect { mailer.deliver }.to raise_error(Hanami::Mailer::MissingRecipientError)
      end
    end

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
      mail = mailer.deliver

      expect(mail.charset).to eq("UTF-8")
    end

    it "allows custom charset" do
      mailer = mailer_class.new
      mail = mailer.deliver(charset: "ISO-2022-JP")

      expect(mail.charset).to eq("ISO-2022-JP")
    end
  end
end
