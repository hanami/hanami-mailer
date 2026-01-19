# frozen_string_literal: true

RSpec.describe "Hanami::Mailer::VERSION" do
  it "returns current version" do
    expect(Hanami::Mailer::VERSION).to eq("2.0.0.alpha1")
  end
end
