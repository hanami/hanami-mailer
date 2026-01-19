# frozen_string_literal: true

module RSpec
  module Support
    module Context
      def self.included(base)
        base.class_eval do
          let(:configuration) do
            configuration = Hanami::Mailer::Configuration.new do |config|
              config.root            = "spec/support/fixtures"
              config.delivery_method = :test
            end

            Hanami::Mailer.finalize(configuration)
          end
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include(RSpec::Support::Context)
end
