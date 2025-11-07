# frozen_string_literal: true

require "ostruct"

RSpec.describe Hanami::Mailer do
  context "constants" do
    it "marks them as private" do
      expect { described_class::CONTENT_TYPES }.to raise_error(NameError)
    end
  end

  context ".finalize" do
    let(:configuration) { Hanami::Mailer::Configuration.new }

    it "finalizes the given configuration" do
      actual = described_class.finalize(configuration)
      expect(actual).to be_frozen
    end
  end

  context "#initialize" do
    let(:configuration) { Hanami::Mailer::Configuration.new }

    it "builds an frozen instance" do
      mailer = described_class.new(configuration: configuration)
      expect(mailer).to be_frozen
    end

    it "prevents memoization mutations" do
      mailer = Class.new(described_class) do
        def self.name
          "memoization_attempt"
        end

        def foo
          @foo ||= "foo"
        end
      end.new(configuration: configuration)

      expect { mailer.foo }.to raise_error(RuntimeError)
    end

    it "prevents accidental configuration removal" do
      mailer = Class.new(described_class) do
        def self.name
          "configuration_removal"
        end

        def foo
          @configuration = nil
        end
      end.new(configuration: configuration)

      expect { mailer.foo }.to raise_error(RuntimeError)
    end
  end

  context "#deliver" do
    context "when mailer has from/to defined with DSL" do
      let(:mailer) { CharsetMailer.new(configuration: configuration) }

      it "delivers email with valid locals" do
        mail = mailer.deliver({})
        expect(mail).to be_kind_of(Mail::Message)
      end

      it "is aliased as #call" do
        mail = mailer.call({})
        expect(mail).to be_kind_of(Mail::Message)
      end

      it "raises error when locals are nil" do
        expect { mailer.deliver(nil) }.to raise_error(NoMethodError)
      end
    end

    context "when from/to are missing" do
      let(:mailer) { InvoiceMailer.new(configuration: configuration) }

      it "raises error" do
        expect { mailer.deliver({}) }.to raise_error(Hanami::Mailer::MissingDeliveryDataError)
      end
    end

    context "when using #{described_class} directly" do
      let(:mailer) do
        described_class.new(configuration: configuration)
      end

      it "raises error" do
        expect { mailer.deliver({}) }.to raise_error(NoMethodError)
      end
    end

    context "with non-finalized configuration" do
      let(:configuration) { Hanami::Mailer::Configuration.new }

      let(:mailer) do
        Class.new(described_class) do
          def self.name
            "anonymous_mailer"
          end
        end.new(configuration: configuration)
      end

      it "raises error" do
        expect { mailer.deliver({}) }.to raise_error(Hanami::Mailer::UnknownMailerError)
      end
    end

    context "locals" do
      let(:mailer) { EventMailer.new(configuration: configuration) }
      let(:user)   { double(name: "Luca", email: "luca@domain.test") }
      let(:event)  { double(id: 23, title: "Event #23") }

      it "uses locals during the delivery process" do
        mail = mailer.deliver(user: user, event: event)

        expect(mail.to).to                      eq(["luca@domain.test"])
        expect(mail.subject).to                 eq("Invitation: Event #23")
        expect(mail.attachments[0].filename).to eq("invitation-23.ics")
      end
    end
  end

  describe "#render" do
    describe "when template is explicitly declared" do
      let(:mailer) { InvoiceMailer.new(configuration: configuration) }

      it "renders the given template" do
        expect(mailer.render(:html, {})).to include(%(<h1>Invoice template</h1>))
      end
    end

    describe "when template is implicitly declared" do
      let(:mailer) { LazyMailer.new(configuration: configuration) }

      it "looks for template with same name with inflected classname and render it" do
        expect(mailer.render(:html, {})).to include(%(Hello World))
        expect(mailer.render(:txt, {})).to include(%(This is a txt template))
      end
    end

    describe "when mailer defines context" do
      let(:mailer) { WelcomeMailer.new(configuration: configuration) }

      it "renders template with defined context" do
        expect(mailer.render(:txt, {})).to include(%(Ahoy))
      end
    end

    describe "when mailer defines layout" do
      let(:mailer) { WithLayoutMailer.new(configuration: configuration) }

      it "renders template inside defined layout" do
        expect(mailer.render(:txt, {})).to include(%(MAIL-HEADER))
        expect(mailer.render(:txt, {})).to include(%(MAIL-FOOTER))
      end
    end

    describe "when locals are parsed in" do
      let(:mailer) { RenderMailer.new(configuration: configuration) }
      let(:locals) { {user: User.new("Luca")} }

      it "renders template with parsed locals" do
        expect(mailer.render(:html, locals)).to include(locals.fetch(:user).name)
      end
    end

    describe "with HAML template engine" do
      let(:mailer) { TemplateEngineMailer.new(configuration: configuration) }
      let(:locals) { {user: User.new("MG")} }

      it "renders template with parsed locals" do
        expect(mailer.render(:html, locals)).to include(%(<h1>\n#{locals.fetch(:user).name}\n</h1>\n))
      end
    end
  end
end
