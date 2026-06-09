# frozen_string_literal: true

RSpec.describe Hanami::Mailer::Delivery::Result do
  subject(:result) { described_class.new(message: message, error: error) }

  let(:message) { instance_double(Hanami::Mailer::Message) }
  let(:error) { nil }

  describe "#success?" do
    context "when there is no error" do
      it "returns true" do
        expect(result.success?).to be true
      end
    end

    context "when there is an error" do
      let(:error) { StandardError.new("boom") }

      it "returns false" do
        expect(result.success?).to be false
      end
    end
  end

  describe "#failure?" do
    context "when there is no error" do
      it "returns false" do
        expect(result.failure?).to be false
      end
    end

    context "when there is an error" do
      let(:error) { StandardError.new("boom") }

      it "returns true" do
        expect(result.failure?).to be true
      end
    end
  end
end
