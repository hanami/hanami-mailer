# frozen_string_literal: true

require "fileutils"

RSpec.describe Hanami::Mailer, "attachments" do
  before do
    Hanami::Mailer::Delivery::Test.clear
  end

  describe "static filename attachment" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Invoice"

        attachment do
          file("invoice.pdf", "PDF content")
        end
      end
    end

    it "attaches file with static filename" do
      mailer = mailer_class.new
      message = mailer.deliver

      expect(message.attachments.size).to eq(1)
      attachment = message.attachments.first
      expect(attachment.filename).to eq("invoice.pdf")
    end
  end

  describe "dynamic attachment from block" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Invoice"

        expose :invoice_number

        attachment do |invoice_number:|
          file(
            "invoice-#{invoice_number}.pdf",
            "PDF content for invoice #{invoice_number}"
          )
        end
      end
    end

    it "generates attachment dynamically" do
      mailer = mailer_class.new
      message = mailer.deliver(invoice_number: 12_345)

      expect(message.attachments.size).to eq(1)
      attachment = message.attachments.first
      expect(attachment.filename).to eq("invoice-12345.pdf")
      expect(attachment.content).to eq("PDF content for invoice 12345")
    end
  end

  describe "multiple attachments" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Order confirmation"

        attachment do
          file("terms.pdf", "Terms content")
        end

        attachment do
          file("logo.png", "Logo content", inline: true)
        end

        attachment do
          file("receipt.txt", "Thank you for your order")
        end
      end
    end

    it "includes all attachments" do
      mailer = mailer_class.new
      message = mailer.deliver

      expect(message.attachments.size).to eq(3)
      filenames = message.attachments.map(&:filename)
      expect(filenames).to include("terms.pdf", "logo.png", "receipt.txt")
    end
  end

  describe "inline attachments" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Newsletter"

        attachment do
          file("logo.png", "Logo content", inline: true)
        end
      end
    end

    it "marks attachment as inline" do
      mailer = mailer_class.new
      message = mailer.deliver

      expect(message.attachments.size).to eq(1)
      attachment = message.attachments.first
      expect(attachment.inline?).to be true
      expect(attachment.content_id).to eq("logo.png")
    end
  end

  describe "attachment with explicit content type" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Data export"

        attachment do
          file(
            "data.csv",
            "Name,Email\nJohn,john@example.com",
            content_type: "text/csv"
          )
        end
      end
    end

    it "uses specified content type" do
      mailer = mailer_class.new
      message = mailer.deliver

      attachment = message.attachments.first
      expect(attachment.content_type).to match(/text\/csv/)
    end
  end

  describe "attachment from instance method" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Report"

        expose :report_id

        attachment :generate_report

        private

        def generate_report(report_id:)
          file(
            "report-#{report_id}.pdf",
            "Report content for #{report_id}"
          )
        end
      end
    end

    it "calls instance method to generate attachment" do
      mailer = mailer_class.new
      message = mailer.deliver(report_id: 999)

      attachment = message.attachments.first
      expect(attachment.filename).to eq("report-999.pdf")
      expect(attachment.content).to eq("Report content for 999")
    end
  end

  describe "returning multiple attachments from one definition" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Multiple files"

        expose :file_count

        attachment do |file_count:|
          file_count.times.map do |i|
            file("file-#{i}.txt", "Content #{i}")
          end
        end
      end
    end

    it "attaches all returned files" do
      mailer = mailer_class.new
      message = mailer.deliver(file_count: 3)

      expect(message.attachments.size).to eq(3)
      expect(message.attachments[0].filename).to eq("file-0.txt")
      expect(message.attachments[1].filename).to eq("file-1.txt")
      expect(message.attachments[2].filename).to eq("file-2.txt")
    end
  end

  describe "attachment MIME type detection" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Files"

        attachment do
          [
            file("doc.pdf", "PDF"),
            file("image.jpg", "JPG"),
            file("sheet.xlsx", "XLSX"),
            file("data.txt", "TXT")
          ]
        end
      end
    end

    it "automatically detects MIME types from filename extensions" do
      mailer = mailer_class.new
      message = mailer.deliver

      pdf = message.attachments.find { |a| a.filename == "doc.pdf" }
      jpg = message.attachments.find { |a| a.filename == "image.jpg" }
      xlsx = message.attachments.find { |a| a.filename == "sheet.xlsx" }
      txt = message.attachments.find { |a| a.filename == "data.txt" }

      expect(pdf.content_type).to match(/application\/pdf/)
      expect(jpg.content_type).to match(/image\/jpeg/)
      expect(xlsx.content_type).to match(/application\/vnd\.openxmlformats/)
      expect(txt.content_type).to match(/text\/plain/)
    end
  end

  describe "attachment_paths configuration" do
    let(:attachment_dir) { File.join(__dir__, "..", "fixtures", "attachments") }

    before do
      FileUtils.mkdir_p(attachment_dir)
      File.write(File.join(attachment_dir, "terms.pdf"), "Terms and conditions content")
      File.write(File.join(attachment_dir, "logo.png"), "Logo image content")
    end

    after do
      FileUtils.rm_rf(attachment_dir)
    end

    let(:mailer_class) do
      dir = attachment_dir
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Invoice"

        config.attachment_paths = [dir]

        attachment "terms.pdf"
        attachment "logo.png"
      end
    end

    it "finds and reads attachment files from configured paths" do
      mailer = mailer_class.new
      message = mailer.deliver

      expect(message.attachments.size).to eq(2)

      terms = message.attachments.find { |a| a.filename == "terms.pdf" }
      logo = message.attachments.find { |a| a.filename == "logo.png" }

      expect(terms.content).to eq("Terms and conditions content")
      expect(logo.content).to eq("Logo image content")
    end

    context "with multiple attachment paths" do
      let(:secondary_dir) { File.join(__dir__, "..", "fixtures", "attachments2") }

      before do
        FileUtils.mkdir_p(secondary_dir)
        File.write(File.join(secondary_dir, "invoice.pdf"), "Invoice content")
      end

      after do
        FileUtils.rm_rf(secondary_dir)
      end

      let(:mailer_class) do
        primary = attachment_dir
        secondary = secondary_dir
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Invoice"

          config.attachment_paths = [primary, secondary]

          attachment "terms.pdf"
          attachment "invoice.pdf"
        end
      end

      it "searches paths in order and finds files" do
        mailer = mailer_class.new
        message = mailer.deliver

        expect(message.attachments.size).to eq(2)

        terms = message.attachments.find { |a| a.filename == "terms.pdf" }
        invoice = message.attachments.find { |a| a.filename == "invoice.pdf" }

        expect(terms.content).to eq("Terms and conditions content")
        expect(invoice.content).to eq("Invoice content")
      end
    end

    context "when file is not found in attachment_paths" do
      let(:mailer_class) do
        dir = attachment_dir
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Invoice"

          config.attachment_paths = [dir]

          attachment "nonexistent.pdf"
        end
      end

      it "raises MissingAttachmentError" do
        mailer = mailer_class.new

        expect {
          mailer.deliver
        }.to raise_error(Hanami::Mailer::MissingAttachmentError, /Attachment file not found: nonexistent\.pdf/)
      end
    end
  end

  describe "error handling" do
    describe "when returning raw hash instead of AttachmentData" do
      let(:mailer_class) do
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Test"

          attachment do
            {filename: "test.pdf", content: "content"}
          end
        end
      end

      it "raises helpful error message" do
        mailer = mailer_class.new

        expect {
          mailer.deliver
        }.to raise_error(ArgumentError, /Attachment blocks must return AttachmentData objects. Use the `file` helper method/)
      end
    end
  end
end
