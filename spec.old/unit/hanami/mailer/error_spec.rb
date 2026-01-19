# frozen_string_literal: true

RSpec.describe Hanami::Mailer::Error do
  it "inherits from StandardError" do
    expect(described_class.ancestors).to include(StandardError)
  end
end
