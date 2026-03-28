# frozen_string_literal: true

require "tmpdir"

RSpec.describe "View integration" do
  let(:mailer) { mailer_class.new }

  describe "with integration enabled (default)" do
    around do |example|
      Dir.mktmpdir do |dir|
        @templates_dir = Pathname(dir)
        example.run
      end
    end

    let(:templates_dir) { @templates_dir }

    def write(path, content)
      templates_dir.join(File.dirname(path)).mkpath
      File.write(templates_dir.join(path), content)
    end

    describe "automatic view building" do
      before do
        write "welcome_mailer.html.erb", "<h1>Welcome <%= name %></h1>"
        write "welcome_mailer.txt.erb", "Welcome <%= name %>"
      end

      let(:mailer_class) {
        dir = templates_dir
        Class.new(Hanami::Mailer) {
          config.paths = [dir]
          config.template = "welcome_mailer"

          from "noreply@example.com"
          to "user@example.com"
          subject "Welcome"

          expose :name
        }
      }

      it "auto-builds view from exposures and config" do
        expect(mailer.view).not_to be_nil
        expect(mailer.view).to be_a(Hanami::View)
      end

      it "renders HTML template" do
        result = mailer.deliver(name: "Alice")

        expect(result.message.html_body).to include("<h1>Welcome Alice</h1>")
      end

      it "renders text template" do
        result = mailer.deliver(name: "Alice")

        expect(result.message.text_body).to include("Welcome Alice")
      end

      it "passes exposures to view rendering" do
        result = mailer.deliver(name: "Bob")

        expect(result.message.html_body).to include("Bob")
        expect(result.message.text_body).to include("Bob")
      end
    end

    describe "exposures passed to view" do
      before do
        write "order_mailer.html.erb", "<p>Order #<%= order_id %> for <%= customer_name %></p>"
      end

      let(:mailer_class) {
        dir = templates_dir
        Class.new(Hanami::Mailer) {
          config.paths = [dir]
          config.template = "order_mailer"

          from "noreply@example.com"
          to "user@example.com"
          subject "Order confirmation"

          expose :order_id
          expose :customer_name do |customer:|
            customer[:name]
          end
        }
      }

      it "passes all exposures to view" do
        result = mailer.deliver(order_id: 12_345, customer: {name: "Bob"})

        expect(result.message.html_body).to include("Order #12345")
        expect(result.message.html_body).to include("Bob")
      end

      it "evaluates computed exposures before passing to view" do
        result = mailer.deliver(order_id: 99_999, customer: {name: "Charlie"})

        expect(result.message.html_body).to include("Charlie")
      end
    end

    describe "template inference" do
      before do
        write "mailers/notification_mailer.html.erb", "<p>Notification content</p>"
      end

      let(:mailer_class) {
        dir = templates_dir
        klass = Class.new(Hanami::Mailer) {
          config.paths = [dir]
          config.template_inference_base = "mailers"

          from "noreply@example.com"
          to "user@example.com"
          subject "Notification"

          expose :message
        }

        stub_const("Mailers::NotificationMailer", klass)
        klass
      }

      it "infers template from class name" do
        result = mailer.deliver(message: "Hello")

        expect(result.message.html_body).to include("Notification content")
      end
    end

    describe "without templates for a format" do
      before do
        write "html_only_mailer.html.erb", "<p>HTML only</p>"
      end

      let(:mailer_class) {
        dir = templates_dir
        Class.new(Hanami::Mailer) {
          config.paths = [dir]
          config.template = "html_only_mailer"

          from "noreply@example.com"
          to "user@example.com"
          subject "HTML only"

          expose :data
        }
      }

      it "returns nil for missing format template" do
        result = mailer.deliver(data: "test")

        expect(result.message.html_body).to include("HTML only")
        expect(result.message.text_body).to be_nil
      end
    end

    describe "inheritance of view configuration" do
      before do
        write "child_mailer.html.erb", "<p>Child template</p>"
      end

      let(:parent_class) {
        dir = templates_dir
        Class.new(Hanami::Mailer) {
          config.paths = [dir]

          from "parent@example.com"

          expose :shared_data
        }
      }

      let(:child_class) {
        Class.new(parent_class) {
          config.template = "child_mailer"

          to "user@example.com"
          subject "Child email"

          expose :child_data
        }
      }

      it "inherits parent paths config" do
        expect(child_class.config.paths).to eq(parent_class.config.paths)
      end

      it "renders using inherited paths" do
        result = child_class.new.deliver(shared_data: "shared", child_data: "child")

        expect(result.message.html_body).to include("Child template")
      end
    end

    describe "explicit view injection overrides auto-building" do
      let(:custom_view) {
        Class.new {
          def call(format:, **)
            "Custom view output"
          end
        }.new
      }

      let(:mailer_class) {
        dir = templates_dir
        Class.new(Hanami::Mailer) {
          config.paths = [dir]
          config.template = "unused"

          from "noreply@example.com"
          to "user@example.com"
          subject "Injected view"

          expose :name
        }
      }

      it "uses injected view instead of auto-building" do
        result = mailer_class.new(view: custom_view).deliver(name: "Test")

        expect(result.message.html_body).to eq("Custom view output")
      end
    end
  end

  describe "with integrate_view disabled" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        config.integrate_view = false

        from "noreply@example.com"
        to "user@example.com"
        subject "Test email"

        expose :name
      }
    }

    it "does not auto-build a view" do
      expect(mailer.view).to be_nil
    end

    it "delivers successfully" do
      result = mailer.deliver(name: "Alice")

      expect(result.success?).to be true
      expect(result.message.html_body).to be_nil
      expect(result.message.text_body).to be_nil
    end

    it "still allows injecting a custom view" do
      custom_view = Class.new {
        def call(format:, **input)
          "Hello #{input[:name]}"
        end
      }.new

      result = mailer_class.new(view: custom_view).deliver(name: "Bob")

      expect(result.message.html_body).to eq("Hello Bob")
    end

    it "inherits the disabled setting to subclasses" do
      child_class = Class.new(mailer_class) { subject "Child" }

      expect(child_class.new.view).to be_nil
    end
  end

  describe "without view config" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "No view email"
      }
    }

    it "has nil view by default when no exposures or paths configured" do
      expect(mailer.view).to be_nil
    end

    it "delivers successfully with nil body" do
      result = mailer.deliver

      expect(result.success?).to be true
      expect(result.message.html_body).to be_nil
      expect(result.message.text_body).to be_nil
    end
  end

  describe "with custom view object" do
    let(:custom_view) {
      Class.new {
        def call(format:, **input)
          case format
          when :html then "<h1>Hello, #{input[:name]}!</h1>"
          when :txt  then "Hello, #{input[:name]}!"
          end
        end
      }.new
    }

    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Custom view email"

        expose :name
      }
    }

    it "uses injected view for rendering" do
      result = mailer_class.new(view: custom_view).deliver(name: "Alice")

      expect(result.message.html_body).to eq("<h1>Hello, Alice!</h1>")
      expect(result.message.text_body).to eq("Hello, Alice!")
    end

    it "passes input to view" do
      result = mailer_class.new(view: custom_view).deliver(name: "Bob")

      expect(result.message.html_body).to include("Bob")
    end

    it "calls view with format parameter" do
      view_spy = Class.new {
        attr_reader :last_format

        def call(format:, **)
          @last_format = format
          "content"
        end
      }.new

      mailer_class.new(view: view_spy).deliver(name: "Test")

      expect(view_spy.last_format).to eq(:html).or eq(:txt)
    end
  end

  describe "view rendering errors" do
    let(:failing_view) {
      Class.new {
        def call(format:, **)
          raise StandardError, "Template not found" if format == :txt

          "<p>HTML works</p>"
        end
      }.new
    }

    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Partial template email"
      }
    }

    it "returns nil for format when rendering fails" do
      result = mailer_class.new(view: failing_view).deliver

      expect(result.message.html_body).to eq("<p>HTML works</p>")
      expect(result.message.text_body).to be_nil
    end

    it "does not raise exception when view rendering fails" do
      expect { mailer_class.new(view: failing_view).deliver }.not_to raise_error
    end
  end

  describe "view with input data" do
    let(:view_with_input) {
      Class.new {
        def call(format:, name:, title: "Mr.")
          case format
          when :html then "<p>#{title} #{name}</p>"
          when :txt  then "#{title} #{name}"
          end
        end
      }.new
    }

    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        expose :name
        expose :title
      }
    }

    it "passes input data to view" do
      result = mailer_class.new(view: view_with_input).deliver(name: "Alice", title: "Dr.")

      expect(result.message.html_body).to include("Dr. Alice")
      expect(result.message.text_body).to include("Dr. Alice")
    end

    it "uses default parameter values when not provided" do
      result = mailer_class.new(view: view_with_input).deliver(name: "Bob")

      expect(result.message.html_body).to include("Mr. Bob")
    end
  end

  describe "preparing message" do
    let(:simple_view) {
      Class.new {
        def call(format:, **)
          case format
          when :html then "<p>Test</p>"
          when :txt  then "Test"
          end
        end
      }.new
    }

    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"
      }
    }

    it "renders view when preparing message" do
      message = mailer_class.new(view: simple_view).prepare

      expect(message).to be_a(Hanami::Mailer::Message)
      expect(message.html_body).to eq("<p>Test</p>")
      expect(message.text_body).to eq("Test")
    end
  end
end
