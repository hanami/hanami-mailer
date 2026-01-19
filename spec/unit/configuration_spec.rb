# frozen_string_literal: true

RSpec.describe Hanami::Mailer, "configuration and delivery" do
  describe "delivery method injection" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"
      end
    end

    it "uses Test delivery by default" do
      mailer = mailer_class.new
      expect(mailer.delivery).to be_a(Hanami::Mailer::Delivery::Test)
    end

    it "allows injecting custom delivery method" do
      require_relative "../../lib/hanami/mailer/delivery/smtp"
      custom_delivery = Hanami::Mailer::Delivery::SMTP.new(address: "smtp.example.com")
      mailer = mailer_class.new(delivery: custom_delivery)

      expect(mailer.delivery).to eq(custom_delivery)
    end

    it "delivers using injected delivery method" do
      test_delivery = Hanami::Mailer::Delivery::Test.new
      mailer = mailer_class.new(delivery: test_delivery)

      Hanami::Mailer::Delivery::Test.clear
      mailer.deliver

      # Should have used the injected delivery instance
      expect(Hanami::Mailer::Delivery::Test.deliveries.size).to eq(1)
    end
  end

  describe "inheritance" do
    it "child mailers inherit parent configuration" do
      parent_class = Class.new(Hanami::Mailer) do
        from "parent@example.com"
        subject "Parent subject"
      end

      child_class = Class.new(parent_class) do
        to "child@example.com"
      end

      mailer = child_class.new
      message = mailer.prepare

      expect(message.from).to eq(["parent@example.com"])
      expect(message.subject).to eq("Parent subject")
      expect(message.to).to eq(["child@example.com"])
    end

    it "child mailers can override parent configuration" do
      parent_class = Class.new(Hanami::Mailer) do
        from "parent@example.com"
        to "user@example.com"
        subject "Parent subject"
      end

      child_class = Class.new(parent_class) do
        from "child@example.com"
        subject "Child subject"
      end

      mailer = child_class.new
      message = mailer.prepare

      expect(message.from).to eq(["child@example.com"])
      expect(message.subject).to eq("Child subject")
    end

    it "child mailers inherit parent exposures" do
      parent_class = Class.new(Hanami::Mailer) do
        expose :user
        expose :greeting
      end

      child_class = Class.new(parent_class) do
        expose :message
      end

      expect(child_class.exposures.key?(:user)).to be true
      expect(child_class.exposures.key?(:greeting)).to be true
      expect(child_class.exposures.key?(:message)).to be true
    end

    it "child mailers inherit parent attachments" do
      parent_class = Class.new(Hanami::Mailer) do
        attachment "terms.pdf"
      end

      child_class = Class.new(parent_class) do
        attachment "logo.png"
      end

      expect(child_class.attachments.definitions.size).to eq(2)
    end
  end
end
