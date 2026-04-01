# frozen_string_literal: true

require "rubygems"
require "bundler"

# Set up essential gems from the Gemfile, but NOT the :integrations group, which ensures hanami-view
# is not made available.
Bundler.setup :default, :development, :test

$LOAD_PATH.unshift "lib"
require "rspec"
