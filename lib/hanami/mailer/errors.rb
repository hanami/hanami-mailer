# frozen_string_literal: true

module Hanami
  class Mailer
    # Base class for Hanami::Mailer errors
    class Error < StandardError; end

    # Raised when a mailer template cannot be found
    class TemplateNotFoundError < Error
      def initialize(mailer)
        super("Template for mailer '#{mailer}' cannot be found")
      end
    end
  end
end
