# frozen_string_literal: true

RSpec.describe Hanami::Mailer, "view integration" do
  describe "with hanami-view" do
    let(:templates_dir) { File.join(__dir__, "..", "fixtures", "templates_with_view") }

    before do
      FileUtils.mkdir_p(templates_dir)
    end

    after do
      FileUtils.rm_rf(templates_dir)
    end

    it "includes ViewIntegration module" do
      expect(Hanami::Mailer.ancestors).to include(Hanami::Mailer::ViewIntegration)
    end

    describe "automatic view building" do
      before do
        File.write(File.join(templates_dir, "welcome_mailer.html.erb"), "<h1>Welcome <%= name %></h1>")
        File.write(File.join(templates_dir, "welcome_mailer.txt.erb"), "Welcome <%= name %>")
      end

      let(:mailer_class) do
        dir = templates_dir
        Class.new(Hanami::Mailer) do
          config.paths = [dir]
          config.template = "welcome_mailer"

          from "noreply@example.com"
          to "user@example.com"
          subject "Welcome"

          expose :name
        end
      end

      it "auto-builds view from exposures and config" do
        mailer = mailer_class.new

        expect(mailer.view).not_to be_nil
        expect(mailer.view).to be_a(Hanami::View)
      end

      it "renders HTML template" do
        mailer = mailer_class.new
        result = mailer.deliver(name: "Alice")

        expect(result.message.html_body).to include("<h1>Welcome Alice</h1>")
      end

      it "renders text template" do
        mailer = mailer_class.new
        result = mailer.deliver(name: "Alice")

        expect(result.message.text_body).to include("Welcome Alice")
      end

      it "passes exposures to view rendering" do
        mailer = mailer_class.new
        result = mailer.deliver(name: "Bob")

        expect(result.message.html_body).to include("Bob")
        expect(result.message.text_body).to include("Bob")
      end
    end

    describe "exposures passed to view" do
      before do
        File.write(
          File.join(templates_dir, "order_mailer.html.erb"),
          "<p>Order #<%= order_id %> for <%= customer_name %></p>"
        )
      end

      let(:mailer_class) do
        dir = templates_dir
        Class.new(Hanami::Mailer) do
          config.paths = [dir]
          config.template = "order_mailer"

          from "noreply@example.com"
          to "user@example.com"
          subject "Order confirmation"

          expose :order_id
          expose :customer_name do |customer:|
            customer[:name]
          end
        end
      end

      it "passes all exposures to view" do
        mailer = mailer_class.new
        result = mailer.deliver(order_id: 12_345, customer: {name: "Bob"})

        expect(result.message.html_body).to include("Order #12345")
        expect(result.message.html_body).to include("Bob")
      end

      it "evaluates computed exposures before passing to view" do
        mailer = mailer_class.new
        result = mailer.deliver(order_id: 99_999, customer: {name: "Charlie"})

        expect(result.message.html_body).to include("Charlie")
      end
    end

    describe "template inference" do
      before do
        FileUtils.mkdir_p(File.join(templates_dir, "mailers"))
        File.write(
          File.join(templates_dir, "mailers", "notification_mailer.html.erb"),
          "<p>Notification content</p>"
        )
      end

      let(:mailer_class) do
        dir = templates_dir
        klass = Class.new(Hanami::Mailer) do
          config.paths = [dir]
          config.template_inference_base = "mailers"

          from "noreply@example.com"
          to "user@example.com"
          subject "Notification"

          expose :message
        end

        stub_const("Mailers::NotificationMailer", klass)
        klass
      end

      it "infers template from class name" do
        mailer = mailer_class.new
        result = mailer.deliver(message: "Hello")

        expect(result.message.html_body).to include("Notification content")
      end
    end

    describe "without templates for a format" do
      before do
        File.write(File.join(templates_dir, "html_only_mailer.html.erb"), "<p>HTML only</p>")
      end

      let(:mailer_class) do
        dir = templates_dir
        Class.new(Hanami::Mailer) do
          config.paths = [dir]
          config.template = "html_only_mailer"

          from "noreply@example.com"
          to "user@example.com"
          subject "HTML only"

          expose :data
        end
      end

      it "returns nil for missing format template" do
        mailer = mailer_class.new
        result = mailer.deliver(data: "test")

        expect(result.message.html_body).to include("HTML only")
        expect(result.message.text_body).to be_nil
      end
    end

    describe "inheritance of view configuration" do
      before do
        File.write(File.join(templates_dir, "child_mailer.html.erb"), "<p>Child template</p>")
      end

      let(:parent_class) do
        dir = templates_dir
        Class.new(Hanami::Mailer) do
          config.paths = [dir]

          from "parent@example.com"

          expose :shared_data
        end
      end

      let(:child_class) do
        Class.new(parent_class) do
          config.template = "child_mailer"

          to "user@example.com"
          subject "Child email"

          expose :child_data
        end
      end

      it "inherits parent paths config" do
        expect(child_class.config.paths).to eq(parent_class.config.paths)
      end

      it "renders using inherited paths" do
        mailer = child_class.new
        result = mailer.deliver(shared_data: "shared", child_data: "child")

        expect(result.message.html_body).to include("Child template")
      end
    end

    describe "explicit view injection overrides auto-building" do
      let(:custom_view) do
        Class.new do
          def call(format:, **)
            "Custom view output"
          end
        end.new
      end

      let(:mailer_class) do
        dir = templates_dir
        Class.new(Hanami::Mailer) do
          config.paths = [dir]
          config.template = "unused"

          from "noreply@example.com"
          to "user@example.com"
          subject "Injected view"

          expose :name
        end
      end

      it "uses injected view instead of auto-building" do
        mailer = mailer_class.new(view: custom_view)
        result = mailer.deliver(name: "Test")

        expect(result.message.html_body).to eq("Custom view output")
      end
    end
  end

  describe "with integrate_view disabled" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        config.integrate_view = false

        from "noreply@example.com"
        to "user@example.com"
        subject "Test email"

        expose :name
      end
    end

    it "does not auto-build a view" do
      expect(mailer_class.new.view).to be_nil
    end

    it "delivers successfully" do
      result = mailer_class.new.deliver(name: "Alice")

      expect(result.success?).to be true
      expect(result.message.html_body).to be_nil
      expect(result.message.text_body).to be_nil
    end

    it "still allows injecting a custom view" do
      custom_view = Class.new do
        def call(format:, **input)
          "Hello #{input[:name]}"
        end
      end.new

      result = mailer_class.new(view: custom_view).deliver(name: "Bob")

      expect(result.message.html_body).to eq("Hello Bob")
    end

    it "inherits the disabled setting to subclasses" do
      child_class = Class.new(mailer_class) { subject "Child" }

      expect(child_class.new.view).to be_nil
    end
  end

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
