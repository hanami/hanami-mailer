# frozen_string_literal: true

RSpec.describe Hanami::Mailer::Finalizer do
  let(:configuration) do
    Hanami::Mailer::Configuration.new do |config|
      config.root = "spec/support/fixtures"
    end
  end

  let(:mailers) { [double("mailer", template_name: "invoice")] }

  describe ".finalize" do
    it "eager autoloads modules from mail gem" do
      expect(Mail).to receive(:eager_autoload!)
      described_class.finalize(mailers, configuration)
    end

    it "adds the mailer to the configuration" do
      expect(configuration).to receive(:add_mailer).with(mailers.first)
      described_class.finalize(mailers, configuration)
    end

    it "returns frozen configuration" do
      actual = described_class.finalize(mailers, configuration)
      expect(actual).to be_frozen
    end
  end
end
