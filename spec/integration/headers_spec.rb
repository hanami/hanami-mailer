# frozen_string_literal: true

RSpec.describe "Headers" do
  let(:mailer) { mailer_class.new }

  describe "static header values" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        header :x_priority, "1"
        header :x_mailer, "Hanami Mailer"
      end
    }

    it "includes headers in the message" do
      result = mailer.deliver

      expect(result.message.headers["X-Priority"]).to eq("1")
      expect(result.message.headers["X-Mailer"]).to eq("Hanami Mailer")
    end
  end

  describe "dynamic header values" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        expose :user_id
        expose :campaign

        header(:x_user_id) { |user_id:| user_id }
        header(:x_campaign) { |campaign:| campaign }
      }
    }

    it "evaluates header blocks with input data" do
      result = mailer.deliver(user_id: "user-123", campaign: "welcome")

      expect(result.message.headers["X-User-Id"]).to eq("user-123")
      expect(result.message.headers["X-Campaign"]).to eq("welcome")
    end
  end

  describe "symbol name normalization" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Newsletter"

        header :x_priority, "1"
        header :list_unsubscribe, "<https://example.com/unsubscribe>"
        header :list_unsubscribe_post, "List-Unsubscribe=One-Click"
        header :precedence, "bulk"
      }
    }

    it "converts symbols to Title-Case with dashes" do
      result = mailer.deliver

      expect(result.message.headers.keys).to include(
        "X-Priority",
        "List-Unsubscribe",
        "List-Unsubscribe-Post",
        "Precedence"
      )
    end
  end

  describe "string name preservation" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        header "X-API-Key", "secret123"
        header "X-Custom-ID", "abc"
        header "x-lowercase", "value"
      }
    }

    it "preserves exact casing for string header names" do
      result = mailer.deliver

      expect(result.message.headers["X-API-Key"]).to eq("secret123")
      expect(result.message.headers["X-Custom-ID"]).to eq("abc")
      expect(result.message.headers["x-lowercase"]).to eq("value")
    end
  end

  describe "mixing standard and custom headers" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        cc "manager@example.com"
        reply_to "support@example.com"
        return_path "bounces@example.com"
        subject "Important notification"

        header :x_priority, "1"
        header :importance, "high"
      }
    }

    it "includes both standard and custom headers" do
      result = mailer.deliver

      expect(result.message.from).to eq(["noreply@example.com"])
      expect(result.message.to).to eq(["user@example.com"])
      expect(result.message.cc).to eq(["manager@example.com"])
      expect(result.message.reply_to).to eq(["support@example.com"])
      expect(result.message.return_path).to eq(["bounces@example.com"])
      expect(result.message.subject).to eq("Important notification")

      expect(result.message.headers["X-Priority"]).to eq("1")
      expect(result.message.headers["Importance"]).to eq("high")
    end
  end

  describe "runtime header overrides" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "default@example.com"
        to "user@example.com"
        subject "Default subject"

        header :x_priority, "3"
        header :x_category, "general"
      }
    }

    it "overrides standard headers at delivery time" do
      result = mailer.deliver(headers: {from: "custom@example.com", subject: "Custom subject"})

      expect(result.message.from).to eq(["custom@example.com"])
      expect(result.message.subject).to eq("Custom subject")
    end

    it "overrides headers at delivery time" do
      result = mailer.deliver(headers: {x_priority: "1", x_category: "urgent"})

      expect(result.message.headers["X-Priority"]).to eq("1")
      expect(result.message.headers["X-Category"]).to eq("urgent")
    end

    it "adds new headers at delivery time" do
      result = mailer.deliver(headers: {x_tracking_id: "track-123"})

      expect(result.message.headers["X-Tracking-Id"]).to eq("track-123")
    end
  end

  describe "headers depending on exposures" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        expose :user
        expose :priority_level do |user:|
          user[:vip] ? "high" : "normal"
        end

        header(:x_priority) do |priority_level:|
          priority_level == "high" ? "1" : "3"
        end

        header(:x_user_tier) do |user:|
          user[:vip] ? "premium" : "standard"
        end
      }
    }

    it "evaluates headers with exposure values" do
      result = mailer.deliver(user: {name: "Alice", vip: true})
      expect(result.message.headers["X-Priority"]).to eq("1")
      expect(result.message.headers["X-User-Tier"]).to eq("premium")

      result = mailer.deliver(user: {name: "Bob", vip: false})
      expect(result.message.headers["X-Priority"]).to eq("3")
      expect(result.message.headers["X-User-Tier"]).to eq("standard")
    end
  end

  describe "inheritance" do
    let(:parent_class) {
      Class.new(Hanami::Mailer) {
        from "parent@example.com"

        header :x_mailer, "Parent Mailer"
        header :x_version, "1.0"
        header :x_category, "parent"
      }
    }

    let(:child_class) {
      Class.new(parent_class) {
        to "user@example.com"
        subject "Child email"

        header :x_category, "child"
        header :x_child_only, "yes"
      }
    }

    it "inherits parent headers" do
      mailer = child_class.new
      result = mailer.deliver

      expect(result.message.headers["X-Mailer"]).to eq("Parent Mailer")
      expect(result.message.headers["X-Version"]).to eq("1.0")
    end

    it "overrides parent headers" do
      mailer = child_class.new
      result = mailer.deliver

      expect(result.message.headers["X-Category"]).to eq("child")
    end

    it "adds child-specific headers" do
      mailer = child_class.new
      result = mailer.deliver

      expect(result.message.headers["X-Child-Only"]).to eq("yes")
    end
  end

  describe "prepare method" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        header :x_custom, "value"
      }
    }

    it "includes headers in prepared message" do
      message = mailer.prepare

      expect(message.headers["X-Custom"]).to eq("value")
    end
  end
end
