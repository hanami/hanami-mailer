# frozen_string_literal: true

RSpec.describe Hanami::Mailer, "runtime attachments" do
  before do
    Hanami::Mailer::Delivery::Test.clear
  end

  describe "attachments parameter" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"
      end
    end

    it "accepts runtime attachments as hashes" do
      mailer = mailer_class.new
      message = mailer.deliver(
        attachments: [
          { filename: "report.pdf", content: "PDF content" }
        ]
      )

      expect(message.attachments.size).to eq(1)
      attachment = message.attachments.first
      expect(attachment.filename).to eq("report.pdf")
      expect(attachment.content).to eq("PDF content")
    end

    it "accepts runtime attachments as AttachmentData objects" do
      mailer = mailer_class.new
      attachment_data = Hanami::Mailer.file("invoice.pdf", "Invoice content")

      message = mailer.deliver(
        attachments: [attachment_data]
      )

      expect(message.attachments.size).to eq(1)
      attachment = message.attachments.first
      expect(attachment.filename).to eq("invoice.pdf")
      expect(attachment.content).to eq("Invoice content")
    end

    it "accepts multiple runtime attachments" do
      mailer = mailer_class.new
      message = mailer.deliver(
        attachments: [
          { filename: "file1.txt", content: "Content 1" },
          { filename: "file2.txt", content: "Content 2" },
          Hanami::Mailer.file("file3.txt", "Content 3")
        ]
      )

      expect(message.attachments.size).to eq(3)
      filenames = message.attachments.map(&:filename)
      expect(filenames).to eq(["file1.txt", "file2.txt", "file3.txt"])
    end

    it "accepts runtime attachments with content_type" do
      mailer = mailer_class.new
      message = mailer.deliver(
        attachments: [
          { filename: "data.csv", content: "a,b,c", content_type: "text/csv" }
        ]
      )

      attachment = message.attachments.first
      expect(attachment.content_type).to match(/text\/csv/)
    end

    it "accepts runtime attachments with inline flag" do
      mailer = mailer_class.new
      message = mailer.deliver(
        attachments: [
          { filename: "logo.png", content: "PNG data", inline: true }
        ]
      )

      attachment = message.attachments.first
      expect(attachment.inline?).to be true
      expect(attachment.content_id).to eq("logo.png")
    end

    it "works with nil attachments parameter" do
      mailer = mailer_class.new
      message = mailer.deliver(attachments: nil)

      expect(message.attachments).to be_empty
    end

    it "works with empty attachments array" do
      mailer = mailer_class.new
      message = mailer.deliver(attachments: [])

      expect(message.attachments).to be_empty
    end
  end

  describe "combining class-level and runtime attachments" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        attachment do
          file("terms.pdf", "Terms content")
        end
      end
    end

    it "includes both class-level and runtime attachments" do
      mailer = mailer_class.new
      message = mailer.deliver(
        attachments: [
          { filename: "invoice.pdf", content: "Invoice content" }
        ]
      )

      expect(message.attachments.size).to eq(2)
      filenames = message.attachments.map(&:filename)
      expect(filenames).to include("terms.pdf", "invoice.pdf")
    end

    it "evaluates class-level attachments with input data" do
      dynamic_mailer = Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"

        expose :report_id

        attachment do |report_id:|
          file("report-#{report_id}.pdf", "Report #{report_id}")
        end
      end

      mailer = dynamic_mailer.new
      message = mailer.deliver(
        report_id: 123,
        attachments: [
          { filename: "cover-letter.pdf", content: "Cover letter" }
        ]
      )

      expect(message.attachments.size).to eq(2)
      filenames = message.attachments.map(&:filename)
      expect(filenames).to include("report-123.pdf", "cover-letter.pdf")
    end
  end

  describe "Hanami::Mailer.file helper" do
    it "creates AttachmentData with filename and content" do
      data = Hanami::Mailer.file("test.pdf", "content")

      expect(data).to be_a(Hanami::Mailer::AttachmentData)
      expect(data.filename).to eq("test.pdf")
      expect(data.content).to eq("content")
      expect(data.inline).to be false
    end

    it "creates AttachmentData with content_type" do
      data = Hanami::Mailer.file("data.csv", "a,b,c", content_type: "text/csv")

      expect(data.content_type).to eq("text/csv")
    end

    it "creates AttachmentData with inline flag" do
      data = Hanami::Mailer.file("logo.png", "PNG", inline: true)

      expect(data.inline).to be true
    end
  end

  describe "duplicate filename detection" do
    context "between runtime attachments" do
      let(:mailer_class) do
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Test"
        end
      end

      it "raises error for duplicate filenames in runtime attachments" do
        mailer = mailer_class.new

        expect {
          mailer.deliver(
            attachments: [
              { filename: "report.pdf", content: "Content A" },
              { filename: "report.pdf", content: "Content B" }
            ]
          )
        }.to raise_error(Hanami::Mailer::DuplicateAttachmentError, /Duplicate attachment filename: "report\.pdf"/)
      end
    end

    context "between class-level attachments" do
      let(:mailer_class) do
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Test"

          attachment do
            file("terms.pdf", "Terms A")
          end

          attachment do
            file("terms.pdf", "Terms B")
          end
        end
      end

      it "raises error for duplicate filenames in class-level attachments" do
        mailer = mailer_class.new

        expect {
          mailer.deliver
        }.to raise_error(Hanami::Mailer::DuplicateAttachmentError, /Duplicate attachment filename: "terms\.pdf"/)
      end
    end

    context "between class-level and runtime attachments" do
      let(:mailer_class) do
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Test"

          attachment do
            file("terms.pdf", "Class-level terms")
          end
        end
      end

      it "raises error when runtime attachment duplicates class-level attachment" do
        mailer = mailer_class.new

        expect {
          mailer.deliver(
            attachments: [
              { filename: "terms.pdf", content: "Runtime terms" }
            ]
          )
        }.to raise_error(Hanami::Mailer::DuplicateAttachmentError, /Duplicate attachment filename: "terms\.pdf"/)
      end
    end

    context "from dynamic class-level attachments" do
      let(:mailer_class) do
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Test"

          expose :files

          attachment do |files:|
            files.map { |f| file("data.csv", f) }
          end
        end
      end

      it "raises error when dynamic attachment returns duplicates" do
        mailer = mailer_class.new

        expect {
          mailer.deliver(files: ["content1", "content2"])
        }.to raise_error(Hanami::Mailer::DuplicateAttachmentError, /Duplicate attachment filename: "data\.csv"/)
      end
    end

    context "with unique filenames" do
      let(:mailer_class) do
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Test"

          attachment do
            file("terms.pdf", "Terms")
          end
        end
      end

      it "does not raise error when all filenames are unique" do
        mailer = mailer_class.new

        expect {
          message = mailer.deliver(
            attachments: [
              { filename: "invoice.pdf", content: "Invoice" },
              { filename: "receipt.pdf", content: "Receipt" }
            ]
          )

          expect(message.attachments.size).to eq(3)
        }.not_to raise_error
      end
    end
  end

  describe "error handling" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"
      end
    end

    it "raises error for attachment hash missing filename" do
      mailer = mailer_class.new

      expect {
        mailer.deliver(
          attachments: [
            { content: "Some content" }
          ]
        )
      }.to raise_error(ArgumentError, /filename is required/)
    end

    it "raises error for attachment hash missing content" do
      mailer = mailer_class.new

      expect {
        mailer.deliver(
          attachments: [
            { filename: "test.pdf" }
          ]
        )
      }.to raise_error(ArgumentError, /content is required/)
    end

    it "raises error for attachment hash with empty filename" do
      mailer = mailer_class.new

      expect {
        mailer.deliver(
          attachments: [
            { filename: "", content: "content" }
          ]
        )
      }.to raise_error(ArgumentError, /filename is required/)
    end
  end

  describe "prepare method with runtime attachments" do
    let(:mailer_class) do
      Class.new(Hanami::Mailer) do
        from "noreply@example.com"
        to "user@example.com"
        subject "Test"
      end
    end

    it "includes runtime attachments in prepared message" do
      mailer = mailer_class.new
      message = mailer.prepare(
        attachments: [
          { filename: "test.pdf", content: "content" }
        ]
      )

      expect(message).to be_a(Hanami::Mailer::Message)
      expect(message.attachments.size).to eq(1)
      expect(message.attachments.first.filename).to eq("test.pdf")
    end
  end
end
