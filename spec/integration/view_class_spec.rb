# frozen_string_literal: true

require "tmpdir"

RSpec.describe "Configurable view_class" do
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

  describe "default" do
    let(:mailer_class) { Class.new(Hanami::Mailer) }

    it "defaults to Hanami::View" do
      expect(mailer_class.config.view_class).to be(Hanami::View)
    end

    it "is inherited by subclasses" do
      child = Class.new(mailer_class)

      expect(child.config.view_class).to be(Hanami::View)
    end
  end

  describe "building from a configured view_class" do
    before do
      write "welcome_mailer.html.erb", "<h1>Welcome <%= name %></h1>"
      write "welcome_mailer.text.erb", "Welcome <%= name %>"
    end

    let(:base_view_class) {
      dir = templates_dir
      Class.new(Hanami::View) {
        config.paths = [dir]
      }
    }

    let(:mailer_class) {
      view = base_view_class
      Class.new(Hanami::Mailer) {
        config.view_class = view
        config.template = "welcome_mailer"

        from "noreply@example.com"
        to "user@example.com"
        subject "Welcome"

        expose :name
      }
    }

    let(:mailer) { mailer_class.new }

    it "builds the view as a subclass of the configured view_class" do
      expect(mailer.view).to be_a(base_view_class)
    end

    it "inherits the base view's paths so no paths need to be set on the mailer" do
      expect(mailer_class.config.paths).to be_empty
      expect(mailer.view).not_to be_nil
    end

    it "renders using the inherited paths" do
      result = mailer.deliver(name: "Alice")

      expect(result.message.html_body).to include("<h1>Welcome Alice</h1>")
      expect(result.message.text_body).to include("Welcome Alice")
    end

    it "applies the mailer's exposures on top of the inherited configuration" do
      result = mailer.deliver(name: "Bob")

      expect(result.message.html_body).to include("Bob")
    end

    it "does not mutate the configured view_class" do
      mailer.view

      expect(base_view_class.config.template).to be_nil
      expect(base_view_class.exposures.exposures).to be_empty
    end
  end

  describe "inheriting view configuration" do
    before do
      write "welcome_mailer.html.erb", "<h1><%= greeting %></h1>"
    end

    let(:context_class) {
      Class.new(Hanami::View::Context) do
        def greeting
          "Hello from context"
        end
      end
    }

    let(:base_view_class) {
      dir = templates_dir
      ctx = context_class
      Class.new(Hanami::View) {
        config.paths = [dir]
        config.default_context = ctx.new
        config.default_format = :html
      }
    }

    let(:mailer_class) {
      view = base_view_class
      Class.new(Hanami::Mailer) {
        config.view_class = view
        config.template = "welcome_mailer"

        from "noreply@example.com"
        to "user@example.com"
        subject "Welcome"
      }
    }

    it "inherits the base view's context" do
      result = mailer_class.new.deliver

      expect(result.message.html_body).to include("Hello from context")
    end

    it "inherits other view settings such as default_format" do
      expect(mailer_class.new.view.config.default_format).to eq(:html)
    end
  end

  describe "mailer overrides take precedence over the base view's configuration" do
    before do
      write "welcome_mailer.html.erb", "<h1>Body</h1>"
    end

    let(:base_view_class) {
      dir = templates_dir
      Class.new(Hanami::View) {
        config.paths = [dir]
        config.default_format = :text
      }
    }

    let(:mailer_class) {
      view = base_view_class
      Class.new(Hanami::Mailer) {
        config.view_class = view
        config.default_format = :html
        config.template = "welcome_mailer"

        from "noreply@example.com"
        to "user@example.com"
        subject "Welcome"
      }
    }

    it "uses the mailer's explicitly configured setting" do
      expect(mailer_class.new.view.config.default_format).to eq(:html)
    end

    it "leaves the base view's configuration untouched" do
      mailer_class.new.view

      expect(base_view_class.config.default_format).to eq(:text)
    end
  end

  describe "explicit mailer paths override the base view's paths" do
    before do
      write "mailer_dir/welcome_mailer.html.erb", "<p>From mailer dir</p>"
      write "base_dir/welcome_mailer.html.erb", "<p>From base dir</p>"
    end

    let(:base_view_class) {
      dir = templates_dir
      Class.new(Hanami::View) {
        config.paths = [dir.join("base_dir")]
      }
    }

    let(:mailer_class) {
      dir = templates_dir
      view = base_view_class
      Class.new(Hanami::Mailer) {
        config.view_class = view
        config.paths = [dir.join("mailer_dir")]
        config.template = "welcome_mailer"

        from "noreply@example.com"
        to "user@example.com"
        subject "Welcome"
      }
    }

    it "renders from the mailer's paths" do
      result = mailer_class.new.deliver

      expect(result.message.html_body).to include("From mailer dir")
    end
  end

  describe "layout" do
    before do
      write "welcome_mailer.html.erb", "BODY"
      write "layouts/app.html.erb", "LAYOUT[<%= yield %>]"
    end

    let(:base_view_class) {
      dir = templates_dir
      Class.new(Hanami::View) {
        config.paths = [dir]
        config.layout = "app"
        config.default_format = :html
      }
    }

    it "does not use the base view's layout unless the mailer configures one" do
      view = base_view_class
      mailer_class = Class.new(Hanami::Mailer) {
        config.view_class = view
        config.template = "welcome_mailer"

        from "noreply@example.com"
        to "user@example.com"
        subject "Welcome"
      }

      result = mailer_class.new.deliver

      expect(result.message.html_body).to eq("BODY")
    end

    it "uses a layout the mailer configures explicitly" do
      view = base_view_class
      mailer_class = Class.new(Hanami::Mailer) {
        config.view_class = view
        config.layout = "app"
        config.template = "welcome_mailer"

        from "noreply@example.com"
        to "user@example.com"
        subject "Welcome"
      }

      result = mailer_class.new.deliver

      expect(result.message.html_body).to eq("LAYOUT[BODY]")
    end
  end

  describe "without paths on the mailer or the view_class" do
    let(:mailer_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "No view"

        expose :name
      }
    }

    it "does not build a view" do
      expect(mailer_class.new.view).to be_nil
    end
  end
end
