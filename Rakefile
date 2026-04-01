# frozen_string_literal: true

require "rake"
require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new do |task|
  file_list = FileList["spec/**/*_spec.rb"]
  file_list = file_list.exclude("spec/isolation/**/*_spec.rb")

  task.pattern = file_list
end

namespace :spec do
  desc "Run isolation tests"
  task :isolation do
    # Run each isolation test with plain `ruby` (not `bundle exec`) inside an unbundled env.
    # This ensures Bundler hasn't pre-activated all gem groups — isolation_helper then calls
    # Bundler.setup with only the groups we want, intentionally excluding :integrations so
    # hanami-view is not available. Using `rspec` or `bundle exec` here would defeat that.
    Dir["spec/isolation/**/*_spec.rb"].each do |test_file|
      puts "\n\nRunning: #{test_file}"
      Bundler.with_unbundled_env do
        system("ruby #{test_file} --options spec/isolation/.rspec") || abort("Isolation test failed: #{test_file}")
      end
    end
  end
end

desc "Run all tests"
task test: ["spec", "spec:isolation"]

task default: :test
