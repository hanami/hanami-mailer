# frozen_string_literal: true

source "https://rubygems.org"
gemspec

unless ENV["CI"]
  gem "byebug", require: false, platforms: :mri
  gem "yard",   require: false
end

gem "hanami-view", "~> 2.1", require: false, git: "https://github.com/hanami/view.git", branch: "main"

gem "hanami-devtools", require: false, git: "https://github.com/hanami/devtools.git", branch: "main"
