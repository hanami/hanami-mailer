# frozen_string_literal: true

RSpec.describe "Format restriction" do
  let(:mailer) { mailer_class.new(view: view) }

  let(:view) {
    Class.new {
      def call(format:, **)
        case format
        when :html then "<h1>Hello World!</h1>"
        when :text then "Hello World!"
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

  describe "without format restriction" do
    it "renders both HTML and text bodies" do
      result = mailer.deliver

      expect(result.message.html_body).to eq("<h1>Hello World!</h1>")
      expect(result.message.text_body).to eq("Hello World!")
    end
  end

  describe "format: :html" do
    it "renders only the HTML body" do
      result = mailer.deliver(format: :html)

      expect(result.message.html_body).to eq("<h1>Hello World!</h1>")
      expect(result.message.text_body).to be_nil
    end
  end

  describe "format: :text" do
    it "renders only the text body" do
      result = mailer.deliver(format: :text)

      expect(result.message.html_body).to be_nil
      expect(result.message.text_body).to eq("Hello World!")
    end
  end

  describe "with prepare" do
    it "respects format restriction in prepare" do
      message = mailer.prepare(format: :text)

      expect(message.html_body).to be_nil
      expect(message.text_body).to eq("Hello World!")
    end
  end

  describe "without a view" do
    let(:mailer) { no_view_class.new }

    let(:no_view_class) {
      Class.new(Hanami::Mailer) {
        from "noreply@example.com"
        to "user@example.com"
        subject "No view"
      }
    }

    it "returns nil bodies regardless of format" do
      result = mailer.deliver(format: :html)

      expect(result.message.html_body).to be_nil
      expect(result.message.text_body).to be_nil
    end
  end
end
