# frozen_string_literal: true

RSpec.describe Hanami::Mailer::Dsl do
  let(:mailer) { Class.new { extend Hanami::Mailer::Dsl } }

  describe ".from" do
    it "returns the default value" do
      expect(mailer.from).to be(nil)
    end

    it "sets the value" do
      sender = "sender@hanami.test"
      mailer.from sender

      expect(mailer.from).to eq(sender)
    end
  end

  describe ".to" do
    it "returns the default value" do
      expect(mailer.to).to be(nil)
    end

    it "sets a single value" do
      recipient = "recipient@hanami.test"
      mailer.to recipient

      expect(mailer.to).to eq(recipient)
    end

    it "sets an array of values" do
      recipients = ["recipient@hanami.test"]
      mailer.to recipients

      expect(mailer.to).to eq(recipients)
    end
  end

  describe ".cc" do
    it "returns the default value" do
      expect(mailer.cc).to be(nil)
    end

    it "sets a single value" do
      recipient = "cc@hanami.test"
      mailer.cc recipient

      expect(mailer.cc).to eq(recipient)
    end

    it "sets an array of values" do
      recipients = ["cc@hanami.test"]
      mailer.cc recipients

      expect(mailer.cc).to eq(recipients)
    end
  end

  describe ".bcc" do
    it "returns the default value" do
      expect(mailer.bcc).to be(nil)
    end

    it "sets a single value" do
      recipient = "bcc@hanami.test"
      mailer.bcc recipient

      expect(mailer.bcc).to eq(recipient)
    end

    it "sets an array of values" do
      recipients = ["bcc@hanami.test"]
      mailer.bcc recipients

      expect(mailer.bcc).to eq(recipients)
    end
  end

  describe ".reply_to" do
    it "returns the default value" do
      expect(mailer.reply_to).to be(nil)
    end

    it "sets a single value" do
      email_address = "reply@hanami.test"
      mailer.reply_to email_address

      expect(mailer.reply_to).to eq(email_address)
    end

    it "sets an array of values" do
      email_addresses = ["bcc@hanami.test"]
      mailer.reply_to email_addresses

      expect(mailer.reply_to).to eq(email_addresses)
    end
  end

  describe ".return_path" do
    it "returns the default value" do
      expect(mailer.return_path).to be(nil)
    end

    it "sets a single value" do
      email_address = "return@hanami.test"
      mailer.return_path email_address

      expect(mailer.return_path).to eq(email_address)
    end

    it "sets an array of values" do
      email_addresses = ["return@hanami.test"]
      mailer.return_path email_addresses

      expect(mailer.return_path).to eq(email_addresses)
    end
  end

  describe ".subject" do
    it "returns the default value" do
      expect(mailer.subject).to be(nil)
    end

    it "sets a value" do
      mail_subject = "Hello"
      mailer.subject mail_subject

      expect(mailer.subject).to eq(mail_subject)
    end
  end

  describe ".template" do
    it "sets a value" do
      mailer.template "file"
    end
  end

  describe ".layout" do
    it "sets a value" do
      mailer.layout "file"
    end
  end

  describe ".template_name" do
    it "returns the default value" do
      expect(mailer.template_name).to be(nil)
    end

    it "returns value, if set" do
      template = "file"
      mailer.template template

      expect(mailer.template_name).to eq(template)
    end
  end

  describe ".before" do
    it "returns the default value" do
      expect(mailer.before).to be_kind_of(Proc)
    end

    it "sets a value" do
      blk = ->(*) {}
      mailer.before(&blk)

      expect(mailer.before).to eq(blk)
    end
  end
end
