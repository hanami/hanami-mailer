# frozen_string_literal: true

RSpec.describe Hanami::Mailer::AttachmentData do
  describe "#initialize" do
    it "stores filename and content" do
      data = described_class.new(filename: "report.pdf", content: "PDF bytes")

      expect(data.filename).to eq("report.pdf")
      expect(data.content).to eq("PDF bytes")
    end

    it "defaults inline to false" do
      data = described_class.new(filename: "file.pdf", content: "content")

      expect(data.inline).to be false
    end

    it "defaults content_type to nil" do
      data = described_class.new(filename: "file.pdf", content: "content")

      expect(data.content_type).to be_nil
    end

    it "accepts a custom content_type" do
      data = described_class.new(filename: "data.csv", content: "a,b,c", content_type: "text/csv")

      expect(data.content_type).to eq("text/csv")
    end

    it "accepts inline: true" do
      data = described_class.new(filename: "logo.png", content: "bytes", inline: true)

      expect(data.inline).to be true
    end

    describe "validation" do
      it "raises ArgumentError when filename is nil" do
        expect {
          described_class.new(filename: nil, content: "content")
        }.to raise_error(ArgumentError, /filename is required/)
      end

      it "raises ArgumentError when filename is an empty string" do
        expect {
          described_class.new(filename: "", content: "content")
        }.to raise_error(ArgumentError, /filename is required/)
      end

      it "raises ArgumentError when content is nil" do
        expect {
          described_class.new(filename: "file.pdf", content: nil)
        }.to raise_error(ArgumentError, /content is required/)
      end

      it "accepts empty string content" do
        expect {
          described_class.new(filename: "empty.txt", content: "")
        }.not_to raise_error
      end
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      data = described_class.new(
        filename: "report.pdf",
        content: "PDF bytes",
        content_type: "application/pdf",
        inline: true
      )

      expect(data.to_h).to eq(
        {
          filename: "report.pdf",
          content: "PDF bytes",
          content_type: "application/pdf",
          inline: true
        }
      )
    end

    it "includes nil content_type when not set" do
      data = described_class.new(filename: "file.txt", content: "hello")

      expect(data.to_h).to eq(
        {
          filename: "file.txt",
          content: "hello",
          content_type: nil,
          inline: false
        }
      )
    end
  end
end
