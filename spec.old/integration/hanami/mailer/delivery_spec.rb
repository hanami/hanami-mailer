# frozen_string_literal: true

RSpec.describe Hanami::Mailer do
  describe ".deliver" do
    it "can deliver with specified charset" do
      mail = CharsetMailer.new(configuration: configuration).deliver(charset: charset = "iso-2022-jp")

      expect(mail.charset).to             eq(charset)
      expect(mail.parts.first.charset).to eq(charset)
    end

    it "raises error when 'from' isn't specified" do
      expect { MissingFromMailer.new(configuration: configuration).deliver({}) }.to raise_error(Hanami::Mailer::MissingDeliveryDataError)
    end

    it "raises error when 'to' isn't specified" do
      expect { MissingToMailer.new(configuration: configuration).deliver({}) }.to raise_error(Hanami::Mailer::MissingDeliveryDataError)
    end

    describe "test delivery with hardcoded values" do
      subject { WelcomeMailer.new(configuration: configuration).deliver({}) }

      it "sends the correct information" do
        expect(subject.from).to    eq(["noreply@sender.com"])
        expect(subject.to).to      eq(["noreply@recipient.com", "owner@recipient.com"])
        expect(subject.cc).to      eq(["cc@recipient.com"])
        expect(subject.bcc).to     eq(["bcc@recipient.com"])
        expect(subject.subject).to eq("Welcome")
      end

      it "has the correct templates" do
        expect(subject.html_part.to_s).to include(%(template))
        expect(subject.text_part.to_s).to include(%(template))
      end

      it "interprets the prepare statement" do
        attachment = subject.attachments["invoice.pdf"]

        expect(attachment).to be_kind_of(Mail::Part)

        expect(attachment).to be_attachment
        expect(attachment).to_not be_inline
        expect(attachment).to_not be_multipart

        expect(attachment.filename).to eq("invoice.pdf")

        expect(attachment.content_type).to match("application/pdf")
        expect(attachment.content_type).to match("filename=invoice.pdf")
      end
    end

    describe "test delivery with procs" do
      subject { ProcMailer.new(configuration: configuration).deliver(user: user) }
      let(:user) { User.new("Name", "student@deigirls.com") }

      it "sends the correct information" do
        expect(subject.from).to    eq(["hello-#{user.name.downcase}@example.com"])
        expect(subject.to).to      eq([user.email])
        expect(subject.subject).to eq("[Hanami] Hello, #{user.name}")
      end
    end

    describe "test delivery with locals" do
      subject     { EventMailer.new(configuration: configuration) }
      let(:count) { 100 }

      it "delivers the message" do
        threads = []
        mails   = {}

        count.times do |i|
          threads << Thread.new do
            user  = double(name: "Luca #{i}", email: "luca-#{i}@domain.test")
            event = double(id: i, title: "Event ##{i}")

            mails[i] = subject.deliver(user: user, event: event)
          end
        end
        threads.map(&:join)

        expect(mails.count).to eq(count)
        mails.each do |i, mail|
          expect(mail.to).to                      eq(["luca-#{i}@domain.test"])
          expect(mail.subject).to                 eq("Invitation: Event ##{i}")
          expect(mail.attachments[0].filename).to eq("invitation-#{i}.ics")
        end
      end
    end

    describe "multipart" do
      it "delivers all the parts by default" do
        mail = WelcomeMailer.new(configuration: configuration).deliver({})
        body = mail.body.encoded

        expect(body).to include(%(<h1>Hello World!</h1>))
        expect(body).to include(%(This is a txt template))
      end

      it "can deliver only the text part" do
        mail = WelcomeMailer.new(configuration: configuration).deliver(format: :txt)
        body = mail.body.encoded

        expect(body).to_not include(%(<h1>Hello World!</h1>))
        expect(body).to     include(%(This is a txt template))
      end

      it "can deliver only the html part" do
        mail = WelcomeMailer.new(configuration: configuration).deliver(format: :html)
        body = mail.body.encoded

        expect(body).to     include(%(<h1>Hello World!</h1>))
        expect(body).to_not include(%(This is a txt template))
      end
    end

    describe "custom delivery" do
      before do
        mailer.deliver({})
      end

      subject       { options.fetch(:deliveries).first }
      let(:mailer)  { WelcomeMailer.new(configuration: configuration) }
      let(:options) { {deliveries: []} }

      let(:configuration) do
        configuration = Hanami::Mailer::Configuration.new do |config|
          config.root            = "spec/support/fixtures"
          config.delivery_method = MandrillDeliveryMethod, options
        end

        Hanami::Mailer.finalize(configuration)
      end

      it "delivers the mail" do
        expect(options.fetch(:deliveries).size).to be(1)
      end

      it "sends the correct information" do
        expect(subject.from).to    eq(["noreply@sender.com"])
        expect(subject.to).to      eq(["noreply@recipient.com", "owner@recipient.com"])
        expect(subject.subject).to eq("Welcome")
      end

      it "has the correct templates" do
        expect(subject.html_part.to_s).to include(%(template))
        expect(subject.text_part.to_s).to include(%(template))
      end

      it "runs the before callback" do
        expect(subject.attachments["invoice.pdf"]).to_not be(nil)
      end
    end
  end
end
