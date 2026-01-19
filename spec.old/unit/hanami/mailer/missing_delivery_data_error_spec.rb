# frozen_string_literal: true

RSpec.describe Hanami::Mailer::MissingDeliveryDataError do
  it "inherits from Hanami::Error" do
    expect(described_class.ancestors).to include(Hanami::Mailer::Error)
  end

  it "has a custom error message" do
    expect {
      raise described_class
    }.to raise_error(described_class, "Missing delivery data, please check 'from', or 'to'")
  end
end
