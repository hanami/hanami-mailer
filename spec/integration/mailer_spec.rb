# frozen_string_literal: true

RSpec.describe "Basic mail delivery" do
  let(:mailer) { mailer_class.new }

  describe "simple mailer with static values" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Welcome to our app"
      }
    }

    it "delivers email with static metadata" do
      result = mailer.deliver

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
      expect(result.message.from).to eq ["noreply@example.com"]
      expect(result.message.to).to eq ["user@example.com"]
      expect(result.message.subject).to eq "Welcome to our app"
    end
  end

  describe "mailer with dynamic values" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to { |user:| user[:email] }
        subject { |user:| "Welcome, #{user[:name]}!" }

        expose :user
      }
    }

    it "evaluates procs with locals" do
      user = {name: "Alice", email: "alice@example.com"}
      result = mailer.deliver(user: user)

      expect(result.message.to).to eq ["alice@example.com"]
      expect(result.message.subject).to eq "Welcome, Alice!"
    end
  end

  describe "mailer with multiple recipients" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to ["user1@example.com", "user2@example.com"]
        cc "manager@example.com"
        bcc "admin@example.com"
        subject "Team notification"
      }
    }

    it "delivers to multiple recipients" do
      result = mailer.deliver

      expect(result.message.to).to eq ["user1@example.com", "user2@example.com"]
      expect(result.message.cc).to eq ["manager@example.com"]
      expect(result.message.bcc).to eq ["admin@example.com"]
    end
  end

  describe "mailer with metadata dependencies on exposures" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
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
      }
    }

    it "evaluates metadata with dependencies on exposures" do
      result = mailer.deliver(user: {name: "Diana", email: "diana@example.com", vip: true})

      expect(result.message.to).to eq ["diana@example.com"]
      expect(result.message.subject).to eq "Greetings, Diana!"
    end

    it "works with non-vip users" do
      result = mailer.deliver(user: {name: "Eve", email: "eve@example.com", vip: false})

      expect(result.message.to).to eq ["eve@example.com"]
      expect(result.message.subject).to eq "Hello, Eve!"
    end
  end

  describe "error handling" do
    describe "missing recipient" do
      let(:mailer_class) {
        Class.new(Hanami::Mailer) {
          from "noreply@example.com"
          subject "Test"
        }
      }

      it "raises error when no recipients are provided" do
        expect { mailer.deliver }.to raise_error(Hanami::Mailer::MissingRecipientError)
      end
    end
  end
end
