# frozen_string_literal: true

RSpec.describe "Hanami::Mailer::VERSION" do
  it "returns current version" do
    expect(Hanami::Mailer::VERSION).to eq("1.1.0")
  end
end
