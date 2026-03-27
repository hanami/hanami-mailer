# frozen_string_literal: true

require_relative "isolation_spec_helper"

# Explicitly require hanami-view BEFORE hanami-mailer so ViewIntegration is included
require "hanami/view"
require "hanami-mailer"
require "fileutils"

RSpec.describe Hanami::Mailer, "with hanami-view" do
  let(:templates_dir) { File.join(__dir__, "..", "fixtures", "templates_with_view") }

  before do
    Hanami::Mailer::Delivery::Test.clear
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

    # Named class for template inference
    module Mailers
      def self.const_missing(name)
        # Allow dynamic class creation for testing
        super
      end
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

      # Give the class a name for template inference
      Mailers.const_set(:NotificationMailer, klass)
      klass
    end

    after do
      Mailers.send(:remove_const, :NotificationMailer) if Mailers.const_defined?(:NotificationMailer)
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

  describe "view settings inheritance" do
    before do
      File.write(File.join(templates_dir, "settings_mailer.html.erb"), "<p>Test</p>")
    end

    it "copies view settings from Hanami::View" do
      dir = templates_dir
      mailer_class = Class.new(Hanami::Mailer) do
        config.paths = [dir]
        config.template = "settings_mailer"

        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        expose :data
      end

      # The mailer should have view-related config settings
      expect(mailer_class.config).to respond_to(:paths)
      expect(mailer_class.config).to respond_to(:template)
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

RSpec::Support::Runner.run
