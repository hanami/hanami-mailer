# frozen_string_literal: true

RSpec.describe Hanami::Mailer, "delivery options" do


  let(:custom_delivery_class) do
    Class.new do
      attr_reader :last_options

      def call(message)
        @last_options = message.delivery_options

        # Simulate using the options for scheduling
        status = message.delivery_options[:send_at] ? "scheduled" : "sent"

        Hanami::Mailer::Delivery::Result.new(
          message: message,
          response: {status: status, options: message.delivery_options}
        )
      end
    end
  end

  describe "passing options to delivery method" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test email"

        expose :scheduled_time

        # Static option
        delivery_option :track_opens, true

        # Dynamic option from block
        delivery_option :send_at do |scheduled_time:|
          scheduled_time
        end
      end
    end

    it "passes static and dynamic options to delivery method" do
      custom_delivery = custom_delivery_class.new
      mailer = mailer_class.new(delivery: custom_delivery)
      scheduled = Time.new(2025, 1, 15, 9, 0, 0)

      result = mailer.deliver(scheduled_time: scheduled)

      expect(custom_delivery.last_options[:track_opens]).to be true
      expect(custom_delivery.last_options[:send_at]).to eq(scheduled)
      expect(result.response[:status]).to eq("scheduled")
    end

    it "evaluates dynamic options with nil values" do
      custom_delivery = custom_delivery_class.new
      mailer = mailer_class.new(delivery: custom_delivery)

      result = mailer.deliver(scheduled_time: nil)

      expect(custom_delivery.last_options[:track_opens]).to be true
      expect(custom_delivery.last_options[:send_at]).to be_nil
      expect(result.response[:status]).to eq("sent")
    end
  end

  describe "empty delivery options" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"
      end
    end

    it "provides empty hash when no options defined" do
      custom_delivery = custom_delivery_class.new
      mailer = mailer_class.new(delivery: custom_delivery)

      mailer.deliver

      expect(custom_delivery.last_options).to eq({})
    end
  end

  describe "inheritance" do
    let(:base_mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"

        delivery_option :track_opens, true
        delivery_option :category, "base"
      end
    end

    let(:child_mailer_class) do
      Class.new(base_mailer_class) do
        to "user@example.com"
        subject "Child mailer"

        delivery_option :category, "child"
        delivery_option :priority, "high"
      end
    end

    it "inherits and overrides parent delivery options" do
      custom_delivery = custom_delivery_class.new
      mailer = child_mailer_class.new(delivery: custom_delivery)

      mailer.deliver

      expect(custom_delivery.last_options[:track_opens]).to be true
      expect(custom_delivery.last_options[:category]).to eq("child")
      expect(custom_delivery.last_options[:priority]).to eq("high")
    end
  end

  describe "options depending on exposures" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        expose :user
        expose :user_type do |user:|
          user[:premium] ? "premium" : "standard"
        end

        delivery_option :priority do |user_type:|
          user_type == "premium" ? "high" : "normal"
        end
      end
    end

    it "evaluates options based on computed exposures" do
      custom_delivery = custom_delivery_class.new
      mailer = mailer_class.new(delivery: custom_delivery)

      mailer.deliver(user: {premium: true})

      expect(custom_delivery.last_options[:priority]).to eq("high")
    end
  end
end
