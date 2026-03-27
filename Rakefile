# frozen_string_literal: true

require "rake"
require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "hanami/devtools/rake_tasks"

namespace :spec do
  RSpec::Core::RakeTask.new(:unit) do |task|
    file_list = FileList["spec/**/*_spec.rb"]
    file_list = file_list.exclude("spec/{integration,isolation}/**/*_spec.rb")

    task.pattern = file_list
  end

  desc "Run isolation tests"
  task :isolation do
    # Run each isolation test in its own Ruby process, using with_unbundled_env to ensure bundler
    # doesn't load extra gems.
    Dir["spec/isolation/**/*_spec.rb"].each do |test_file|
      puts "\n\nRunning: #{test_file}"
      Bundler.with_unbundled_env do
        system("ruby #{test_file} --options spec/isolation/.rspec") || abort("Isolation test failed: #{test_file}")
      end
    end
  end

  RSpec::Core::RakeTask.new(:integration) do |task|
    task.pattern = "spec/integration/**/*_spec.rb"
  end
end

desc "Run all tests"
task test: ["spec:unit", "spec:isolation", "spec:integration"]

task default: "spec:unit"
