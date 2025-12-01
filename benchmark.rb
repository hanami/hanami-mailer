# frozen_string_literal: true

require "bundler/setup"
require "hanami/mailer"
require "benchmark/ips"
require "allocation_stats"
require_relative "examples/base"

configuration = Hanami::Mailer::Configuration.new do |config|
  config.root            = "examples/base"
  config.delivery_method = :test
end

configuration = Hanami::Mailer.finalize(configuration)

invoice = Invoice.new(1, 23)
user    = User.new("Luca", "luca@domain.test")

mailer = InvoiceMailer.new(configuration: configuration)

Benchmark.ips do |x|
  # # Configure the number of seconds used during
  # # the warmup phase (default 2) and calculation phase (default 5)
  # x.config(time: 5, warmup: 2)
  x.report "deliver" do
    mailer.deliver(invoice: invoice, user: user)
  end
end

stats = AllocationStats.new(burn: 5).trace do
  1_000.times do
    mailer.deliver(invoice: invoice, user: user)
  end
end

total_allocations = stats.allocations.all.size
puts "total allocations: #{total_allocations}"

total_memsize = stats.allocations.bytes.to_a.inject(&:+)
puts "total memsize: #{total_memsize}"

detailed_allocations = stats.allocations(alias_paths: true)
  .group_by(:sourcefile, :class_plus)
  .sort_by_count
  .to_text

puts "allocations by source file and class:"
puts detailed_allocations
