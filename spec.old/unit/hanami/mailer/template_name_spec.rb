# frozen_string_literal: true

RSpec.describe Hanami::Mailer::TemplateName do
  describe ".call" do
    context "with top level namespace" do
      let(:namespace) { Object }

      it "returns an instance of ::String" do
        template_name = described_class.call("template", namespace)
        expect(template_name).to be_kind_of(String)
      end

      it "returns name from plain name" do
        template_name = described_class.call("template", namespace)
        expect(template_name).to eq("template")
      end

      it "returns name from camel case name" do
        template_name = described_class.call("ATemplate", namespace)
        expect(template_name).to eq("a_template")
      end

      it "returns name from snake case name" do
        template_name = described_class.call("a_template", namespace)
        expect(template_name).to eq("a_template")
      end

      it "returns name from modulized name" do
        template_name = described_class.call("Mailers::WelcomeMailer", namespace)
        expect(template_name).to eq("mailers/welcome_mailer")
      end

      it "returns name from class" do
        template_name = described_class.call(InvoiceMailer.name, namespace)
        expect(template_name).to eq("invoice_mailer")
      end

      it "returns name from modulized class" do
        template_name = described_class.call(Users::Welcome.name, namespace)
        expect(template_name).to eq("users/welcome")
      end

      it "returns blank string from blank name" do
        template_name = described_class.call("", namespace)
        expect(template_name).to eq("")
      end

      it "raises error with nil name" do
        expect { described_class.call(nil, namespace) }.to raise_error(NoMethodError)
      end
    end

    context "with application namespace" do
      let(:namespace) { Web::Mailers }

      it "returns name from class name" do
        template_name = described_class.call("SignupMailer", namespace)
        expect(template_name).to eq("signup_mailer")
      end

      it "returns name from modulized class name" do
        template_name = described_class.call(Web::Mailers::SignupMailer.name, namespace)
        expect(template_name).to eq("signup_mailer")
      end
    end
  end
end
