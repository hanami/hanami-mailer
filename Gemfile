# frozen_string_literal: true

source "https://rubygems.org"

eval_gemfile "Gemfile.devtools"

gemspec

group :tools do
  gem "debug", platform: :mri
end

group :docs do
  gem "redcarpet", platform: :mri
  gem "yard"
  gem "yard-junk"
end

group :integrations do
  gem "hanami-view", github: "hanami/view", branch: "main"
end

group :test do
  gem "rspec", "~> 3.9"
end
