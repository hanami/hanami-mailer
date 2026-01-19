# frozen_string_literal: true

RSpec.describe Hanami::Mailer::UnknownMailerError do
  it "inherits from Hanami::Error" do
    expect(described_class.ancestors).to include(Hanami::Mailer::Error)
  end

  it "has a custom error message" do
    mailer = InvoiceMailer
    expect {
      raise described_class.new(mailer)
    }.to raise_error(
      described_class,
      "Unknown mailer: #{mailer}. Please finalize the configuration before to use it."
    )
  end

  it "has explicit handling for nil" do
    mailer = nil
    expect {
      raise described_class.new(mailer)
    }.to raise_error(
      described_class,
      "Unknown mailer: #{mailer.inspect}. Please finalize the configuration before to use it."
    )
  end
end
