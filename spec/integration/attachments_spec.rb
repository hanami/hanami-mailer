# frozen_string_literal: true

RSpec.describe "Attachments" do
  let(:mailer) { mailer_class.new }

  describe "class-level attachments" do
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
        result = mailer.deliver

        expect(result.message.attachments.size).to eq(1)
        attachment = result.message.attachments.first
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
        result = mailer.deliver(invoice_number: 12_345)

        expect(result.message.attachments.size).to eq(1)
        attachment = result.message.attachments.first
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
            file("receipt.txt", "Thank you for your order")
          end
        end
      end

      it "includes all attachments" do
        result = mailer.deliver

        expect(result.message.attachments.size).to eq(2)
        filenames = result.message.attachments.map(&:filename)
        expect(filenames).to include("terms.pdf", "receipt.txt")
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
        result = mailer.deliver

        expect(result.message.attachments.size).to eq(1)

        attachment = result.message.attachments.first
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
        result = mailer.deliver

        attachment = result.message.attachments.first
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
        result = mailer.deliver(report_id: 999)

        attachment = result.message.attachments.first
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
        result = mailer.deliver(file_count: 3)

        expect(result.message.attachments.size).to eq(3)
        expect(result.message.attachments[0].filename).to eq("file-0.txt")
        expect(result.message.attachments[1].filename).to eq("file-1.txt")
        expect(result.message.attachments[2].filename).to eq("file-2.txt")
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
        result = mailer.deliver

        pdf = result.message.attachments.find { |a| a.filename == "doc.pdf" }
        jpg = result.message.attachments.find { |a| a.filename == "image.jpg" }
        xlsx = result.message.attachments.find { |a| a.filename == "sheet.xlsx" }
        txt = result.message.attachments.find { |a| a.filename == "data.txt" }

        expect(pdf.content_type).to match(/application\/pdf/)
        expect(jpg.content_type).to match(/image\/jpeg/)
        expect(xlsx.content_type).to match(/application\/vnd\.openxmlformats/)
        expect(txt.content_type).to match(/text\/plain/)
      end
    end

    describe "attachment_paths configuration" do
      let(:attachment_dir) { File.join(__dir__, "..", "fixtures", "attachments") }

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
        result = mailer.deliver

        expect(result.message.attachments.size).to eq(2)

        terms = result.message.attachments.find { |a| a.filename == "terms.pdf" }
        logo = result.message.attachments.find { |a| a.filename == "logo.png" }

        expect(terms.content).to eq("Terms and conditions content")
        expect(logo.content).to eq("Logo image content")
      end

      context "with multiple attachment paths" do
        let(:secondary_dir) { File.join(__dir__, "..", "fixtures", "attachments_2") }

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
          result = mailer.deliver

          expect(result.message.attachments.size).to eq(2)

          terms = result.message.attachments.find { |a| a.filename == "terms.pdf" }
          invoice = result.message.attachments.find { |a| a.filename == "invoice.pdf" }

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
          expect {
            mailer.deliver
          }.to raise_error(Hanami::Mailer::MissingAttachmentError, /Attachment file not found: nonexistent\.pdf/)
        end
      end
    end

    describe "error handling" do
      it "raises ArgumentError when the attachment block returns a non-AttachmentData value" do
        mailer_class = Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Test"

          attachment do
            "my attachment"
          end
        end

        expect {
          mailer_class.new.deliver
        }.to raise_error(ArgumentError, /AttachmentData/)
      end
    end
  end

  describe "runtime attachments" do
    describe "attachments parameter" do
      let(:mailer_class) do
        Class.new(Hanami::Mailer) do
          from "noreply@example.com"
          to "user@example.com"
          subject "Test"
        end
      end

      it "accepts runtime attachments as hashes" do
        result = mailer.deliver(
          attachments: [
            {filename: "report.pdf", content: "PDF content"}
          ]
        )

        expect(result.message.attachments.size).to eq(1)
        attachment = result.message.attachments.first
        expect(attachment.filename).to eq("report.pdf")
        expect(attachment.content).to eq("PDF content")
      end

      it "accepts runtime attachments as AttachmentData objects" do
        attachment_data = Hanami::Mailer.file("invoice.pdf", "Invoice content")

        result = mailer.deliver(
          attachments: [attachment_data]
        )

        expect(result.message.attachments.size).to eq(1)
        attachment = result.message.attachments.first
        expect(attachment.filename).to eq("invoice.pdf")
        expect(attachment.content).to eq("Invoice content")
      end

      it "accepts multiple runtime attachments" do
        result = mailer.deliver(
          attachments: [
            {filename: "file1.txt", content: "Content 1"},
            {filename: "file2.txt", content: "Content 2"},
            Hanami::Mailer.file("file3.txt", "Content 3")
          ]
        )

        expect(result.message.attachments.size).to eq(3)
        filenames = result.message.attachments.map(&:filename)
        expect(filenames).to eq(["file1.txt", "file2.txt", "file3.txt"])
      end

      it "accepts runtime attachments with content_type" do
        result = mailer.deliver(
          attachments: [
            {filename: "data.csv", content: "a,b,c", content_type: "text/csv"}
          ]
        )

        attachment = result.message.attachments.first
        expect(attachment.content_type).to match(/text\/csv/)
      end

      it "accepts runtime attachments with inline flag" do
        result = mailer.deliver(
          attachments: [
            {filename: "logo.png", content: "PNG data", inline: true}
          ]
        )

        attachment = result.message.attachments.first
        expect(attachment.inline?).to be true
        expect(attachment.content_id).to eq("logo.png")
      end

      it "works with nil attachments parameter" do
        result = mailer.deliver(attachments: nil)

        expect(result.message.attachments).to be_empty
      end

      it "works with empty attachments array" do
        result = mailer.deliver(attachments: [])

        expect(result.message.attachments).to be_empty
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
        result = mailer.deliver(
          attachments: [
            {filename: "invoice.pdf", content: "Invoice content"}
          ]
        )

        expect(result.message.attachments.size).to eq(2)
        filenames = result.message.attachments.map(&:filename)
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
        result = mailer.deliver(
          report_id: 123,
          attachments: [
            {filename: "cover-letter.pdf", content: "Cover letter"}
          ]
        )

        expect(result.message.attachments.size).to eq(2)
        filenames = result.message.attachments.map(&:filename)
        expect(filenames).to include("report-123.pdf", "cover-letter.pdf")
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
        message = mailer.prepare(
          attachments: [
            {filename: "test.pdf", content: "content"}
          ]
        )

        expect(message).to be_a(Hanami::Mailer::Message)
        expect(message.attachments.size).to eq(1)
        expect(message.attachments.first.filename).to eq("test.pdf")
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
        expect {
          mailer.deliver(
            attachments: [
              {content: "Some content"}
            ]
          )
        }.to raise_error(ArgumentError, /filename is required/)
      end

      it "raises error for attachment hash missing content" do
        expect {
          mailer.deliver(
            attachments: [
              {filename: "test.pdf"}
            ]
          )
        }.to raise_error(ArgumentError, /content is required/)
      end

      it "raises error for attachment hash with empty filename" do
        expect {
          mailer.deliver(
            attachments: [
              {filename: "", content: "content"}
            ]
          )
        }.to raise_error(ArgumentError, /filename is required/)
      end
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
        expect {
          mailer.deliver(
            attachments: [
              {filename: "report.pdf", content: "Content A"},
              {filename: "report.pdf", content: "Content B"}
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
        expect {
          mailer.deliver(
            attachments: [
              {filename: "terms.pdf", content: "Runtime terms"}
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
        expect {
          result = mailer.deliver(
            attachments: [
              {filename: "invoice.pdf", content: "Invoice"},
              {filename: "receipt.pdf", content: "Receipt"}
            ]
          )

          expect(result.message.attachments.size).to eq(3)
        }.not_to raise_error
      end
    end
  end
end
