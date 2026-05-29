# frozen_string_literal: true

RSpec.describe Hanami::Mailer::Delivery::Test do
  let(:message) { minimal_message }
  let(:delivery) { described_class.new }

  describe "#deliveries" do
    it "is empty after clear" do
      delivery.clear

      expect(delivery.deliveries).to be_empty
    end

    it "accumulates results across multiple calls" do
      delivery.call(message)
      delivery.call(message)

      expect(delivery.deliveries.size).to eq(2)
    end
  end

  describe "#clear" do
    it "empties the deliveries collection" do
      delivery.call(message)
      delivery.clear

      expect(delivery.deliveries).to be_empty
    end
  end

  describe "#call" do
    it "returns a successful Result" do
      result = delivery.call(message)

      expect(result).to be_a(Hanami::Mailer::Delivery::Result)
      expect(result.success?).to be true
    end

    it "includes the message in the result" do
      result = delivery.call(message)

      expect(result.message).to be(message)
    end

    it "returns nil for the response" do
      result = delivery.call(message)

      expect(result.response).to be_nil
    end

    it "returns nil for the error" do
      result = delivery.call(message)

      expect(result.error).to be_nil
    end

    it "stores the result in the instance-level deliveries" do
      result = delivery.call(message)

      expect(delivery.deliveries).to include(result)
    end
  end

  describe "#preview" do
    it "returns the message unchanged" do
      returned = delivery.preview(message)

      expect(returned).to be(message)
    end
  end
end
