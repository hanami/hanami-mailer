# frozen_string_literal: true

RSpec.describe Hanami::Mailer::Template do
  subject    { described_class.new(file) }
  let(:file) { "spec/support/fixtures/templates/welcome_mailer.txt.erb" }

  describe "#initialize" do
    context "with existing file" do
      it "instantiates template" do
        expect(subject).to be_kind_of(described_class)
      end

      it "initialize frozen instance" do
        expect(subject).to be_frozen
      end
    end

    context "with missing template engine" do
      it "returns error" do
        expect {
          described_class.new("Gemfile")
        }.to raise_error(RuntimeError, "No template engine registered for Gemfile")
      end
    end

    context "with unexisting file" do
      it "returns error" do
        expect { described_class.new("foo.erb") }.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe "#render" do
    it "renders template" do
      scope  = Object.new
      actual = subject.render(scope, greeting: "Hello")

      expect(actual).to eq("This is a txt template\nHello")
    end

    it "renders with unfrozen object" do
      scope = Object.new
      expect(scope).to receive(:dup)

      subject.render(scope, greeting: "Hello")
    end
  end
end
