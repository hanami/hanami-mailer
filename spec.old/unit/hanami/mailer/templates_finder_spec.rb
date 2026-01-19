# frozen_string_literal: true

RSpec.describe Hanami::Mailer::TemplatesFinder do
  subject { described_class.new(root) }
  # NOTE: please do not change this name, because `#find` specs are relying on
  # template fixtures. See all the fixtures under: spec/support/fixtures/templates
  let(:template_name) { "welcome_mailer" }
  let(:root)          { configuration.root }

  describe "#initialize" do
    context "with valid root" do
      it "instantiates a new finder instance" do
        expect(subject).to be_kind_of(described_class)
      end

      it "returns a frozen object" do
        expect(subject).to be_frozen
      end
    end

    context "with unexisting root" do
      let(:root) { "path/to/unexisting" }

      it "raises error" do
        expect { subject }.to raise_error(Errno::ENOENT)
      end
    end

    context "with nil root" do
      let(:root) { nil }

      it "raises error" do
        expect { subject }.to raise_error(TypeError)
      end
    end
  end

  describe "#find" do
    context "with valid template name" do
      it "returns templates" do
        actual = subject.find(template_name)

        # It excludes all the files that aren't matching the convention:
        #
        #   `<template_name>.<format>.<template_engine>`
        #
        # Under `spec/support/fixtures/templates` we have the following files:
        #
        #   * welcome_mailer
        #   * welcome_mailer.erb
        #   * welcome_mailer.html
        #   * welcome_mailer.html.erb
        #   * welcome_mailer.txt.erb
        #
        # Only the last two are matching the pattern, here's why we have only
        # two templates loaded.
        expect(actual.keys).to eq(%i[html txt])
        actual.each_value do |template|
          expect(template).to be_kind_of(Hanami::Mailer::Template)
          expect(template.instance_variable_get(:@_template).__send__(:file))
            .to match(%r{spec/support/fixtures/templates/welcome_mailer.(html|txt).erb})
        end
      end
    end

    context "with missing template" do
      let(:template_name) { "missing_template" }

      it "doesn't return templates" do
        actual = subject.find(template_name)

        expect(actual).to be_empty
      end
    end
  end
end
