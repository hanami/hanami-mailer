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

  describe ".new" do
    context "when success: contradicts the presence of error" do
      it "raises when success is true but an error is given" do
        expect {
          described_class.new(message: message, success: true, error: StandardError.new("boom"))
        }.to raise_error(ArgumentError, /inconsistent/)
      end

      it "raises when success is false but no error is given" do
        expect {
          described_class.new(message: message, success: false, error: nil)
        }.to raise_error(ArgumentError, /inconsistent/)
      end
    end

    context "when success: is consistent with error" do
      it "accepts success: false with an error" do
        result = described_class.new(message: message, success: false, error: StandardError.new("boom"))

        expect(result.failure?).to be true
      end

      it "accepts success: true with no error" do
        result = described_class.new(message: message, success: true, error: nil)

        expect(result.success?).to be true
      end
    end
  end
end
