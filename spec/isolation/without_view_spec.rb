# frozen_string_literal: true

require_relative "isolation_spec_helper"

if defined?(Hanami::View)
  raise "This spec must run without hanami-view loaded."
end

require "hanami-mailer"

RSpec.describe "Without hanami-view" do
  it "doesn't load Hanami::View" do
    expect(defined?(Hanami::View)).to be(nil)
  end

  it "doesn't include ViewIntegration module" do
    expect(Hanami::Mailer.ancestors).not_to include(Hanami::Mailer::ViewIntegration)
  end

  it "doesn't have view-specific config settings" do
    mailer_class = Class.new(Hanami::Mailer)

    # Should not have view-specific settings like template_inference_base
    expect(mailer_class.config).not_to respond_to(:template_inference_base)
  end

  describe "mailer with exposures" do
    before do
      Hanami::Mailer::Delivery::Test.clear
    end
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test email"

        expose :name
        expose :greeting do |name:|
          "Hello, #{name}!"
        end
      end
    end

    it "has nil view by default" do
      mailer = mailer_class.new

      expect(mailer.view).to be_nil
    end

    it "delivers successfully without a view" do
      mailer = mailer_class.new
      result = mailer.deliver(name: "Alice")

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
    end

    it "has nil html_body and text_body" do
      mailer = mailer_class.new
      result = mailer.deliver(name: "Alice")

      expect(result.message.html_body).to be_nil
      expect(result.message.text_body).to be_nil
    end

    it "still evaluates exposures" do
      mailer = mailer_class.new
      message = mailer.prepare(name: "Bob")

      # Exposures are evaluated even without a view
      expect(message.subject).to eq("Test email")
    end

    it "includes standard headers" do
      mailer = mailer_class.new
      result = mailer.deliver(name: "Charlie")

      expect(result.message.from).to eq(["noreply@example.com"])
      expect(result.message.to).to eq(["user@example.com"])
      expect(result.message.subject).to eq("Test email")
    end
  end

  describe "mailer with custom headers and attachments" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Full featured email"

        header :x_mailer, "Hanami Mailer"
        header :x_priority, "1"

        expose :filename

        attachment do |filename:|
          file(filename, "attachment content")
        end
      end
    end

    it "processes custom headers without view integration" do
      mailer = mailer_class.new
      result = mailer.deliver(filename: "test.pdf")

      expect(result.message.headers["X-Mailer"]).to eq("Hanami Mailer")
      expect(result.message.headers["X-Priority"]).to eq("1")
    end

    it "processes attachments without view integration" do
      mailer = mailer_class.new
      result = mailer.deliver(filename: "report.pdf")

      expect(result.message.attachments.size).to eq(1)
      expect(result.message.attachments.first.filename).to eq("report.pdf")
    end
  end

  describe "with custom view object injected" do
    let(:custom_view) do
      Class.new do
        def call(format:, **input)
          case format
          when :html
            "<p>Hello #{input[:name]}</p>"
          when :txt
            "Hello #{input[:name]}"
          end
        end
      end.new
    end

    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Custom view"

        expose :name
      end
    end

    it "can still use an injected view object" do
      mailer = mailer_class.new(view: custom_view)

      expect(mailer.view).to eq(custom_view)
    end

    it "renders using the injected view" do
      mailer = mailer_class.new(view: custom_view)
      result = mailer.deliver(name: "Alice")

      expect(result.message.html_body).to eq("<p>Hello Alice</p>")
      expect(result.message.text_body).to eq("Hello Alice")
    end
  end

  describe "inheritance" do
    let(:parent_class) do
      Class.new(Hanami::Mailer) do
        from "parent@example.com"
        expose :shared
      end
    end

    let(:child_class) do
      Class.new(parent_class) do
        to "user@example.com"
        subject "Child email"
        expose :child_only
      end
    end

    it "inherits exposures without view integration" do
      expect(child_class.exposures.key?(:shared)).to be true
      expect(child_class.exposures.key?(:child_only)).to be true
    end

    it "delivers successfully" do
      mailer = child_class.new
      result = mailer.deliver(shared: "A", child_only: "B")

      expect(result.success?).to be true
      expect(result.message.from).to eq(["parent@example.com"])
      expect(result.message.to).to eq(["user@example.com"])
    end
  end
end

RSpec::Support::Runner.run
