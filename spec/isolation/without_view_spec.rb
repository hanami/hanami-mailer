# frozen_string_literal: true

require_relative "isolation_helper"

require "hanami-mailer"

RSpec.describe Hanami::Mailer, "without hanami-view" do
  it "does not include ViewIntegration" do
    expect(Hanami::Mailer.ancestors).not_to include(Hanami::Mailer::ViewIntegration)
  end

  it "delivers successfully without view integration" do
    mailer_class = Class.new(Hanami::Mailer) do
      from "noreply@example.com"
      to "user@example.com"
      subject "Test"
    end

    result = mailer_class.new.deliver

    expect(result.success?).to be true
    expect(result.message.html_body).to be_nil
    expect(result.message.text_body).to be_nil
  end
end

# Execute the RSpec examples (since isolation specs are run via plain `ruby`).
RSpec::Core::Runner.autorun
