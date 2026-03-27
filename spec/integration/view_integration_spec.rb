# frozen_string_literal: true

RSpec.describe Hanami::Mailer, "view integration" do
  describe "without a view" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "No view email"
      end
    end

    it "has nil view by default when no exposures or paths configured" do
      mailer = mailer_class.new

      expect(mailer.view).to be_nil
    end

    it "delivers successfully with nil body" do
      mailer = mailer_class.new
      result = mailer.deliver

      expect(result.success?).to be true
      expect(result.message.html_body).to be_nil
      expect(result.message.text_body).to be_nil
    end

    it "allows explicit view: nil" do
      mailer = mailer_class.new(view: nil)

      expect(mailer.view).to be_nil
    end
  end

  describe "with custom view object" do
    let(:custom_view) do
      Class.new do
        def call(format:, **input)
          case format
          when :html
            "<h1>Hello, #{input[:name]}!</h1>"
          when :txt
            "Hello, #{input[:name]}!"
          end
        end
      end.new
    end

    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Custom view email"

        expose :name
      end
    end

    it "uses injected view for rendering" do
      mailer = mailer_class.new(view: custom_view)
      result = mailer.deliver(name: "Alice")

      expect(result.message.html_body).to eq("<h1>Hello, Alice!</h1>")
      expect(result.message.text_body).to eq("Hello, Alice!")
    end

    it "passes input to view" do
      mailer = mailer_class.new(view: custom_view)
      result = mailer.deliver(name: "Bob")

      expect(result.message.html_body).to include("Bob")
    end

    it "calls view with format parameter" do
      view_spy = Class.new do
        attr_reader :last_format

        def call(format:, **)
          @last_format = format
          "content"
        end
      end.new

      mailer = mailer_class.new(view: view_spy)
      mailer.deliver(name: "Test")

      expect(view_spy.last_format).to eq(:html).or eq(:txt)
    end
  end

  describe "view rendering errors" do
    let(:failing_view) do
      Class.new do
        def call(format:, **)
          raise StandardError, "Template not found" if format == :txt

          "<p>HTML works</p>"
        end
      end.new
    end

    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Partial template email"
      end
    end

    it "returns nil for format when rendering fails" do
      mailer = mailer_class.new(view: failing_view)
      result = mailer.deliver

      expect(result.message.html_body).to eq("<p>HTML works</p>")
      expect(result.message.text_body).to be_nil
    end

    it "does not raise exception when view rendering fails" do
      mailer = mailer_class.new(view: failing_view)

      expect { mailer.deliver }.not_to raise_error
    end
  end

  describe "view with input data" do
    let(:view_with_input) do
      Class.new do
        def call(format:, name:, title: "Mr.")
          case format
          when :html
            "<p>#{title} #{name}</p>"
          when :txt
            "#{title} #{name}"
          end
        end
      end.new
    end

    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        expose :name
        expose :title
      end
    end

    it "passes input data to view" do
      mailer = mailer_class.new(view: view_with_input)
      result = mailer.deliver(name: "Alice", title: "Dr.")

      expect(result.message.html_body).to include("Dr. Alice")
      expect(result.message.text_body).to include("Dr. Alice")
    end

    it "uses default parameter values when not provided" do
      mailer = mailer_class.new(view: view_with_input)
      result = mailer.deliver(name: "Bob")

      expect(result.message.html_body).to include("Mr. Bob")
    end
  end

  describe "prepare method with view" do
    let(:simple_view) do
      Class.new do
        def call(format:, **)
          case format
          when :html then "<p>Test</p>"
          when :txt then "Test"
          end
        end
      end.new
    end

    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"
      end
    end

    it "renders view when preparing message" do
      mailer = mailer_class.new(view: simple_view)
      message = mailer.prepare

      expect(message).to be_a(Hanami::Mailer::Message)
      expect(message.html_body).to eq("<p>Test</p>")
      expect(message.text_body).to eq("Test")
    end
  end
end
