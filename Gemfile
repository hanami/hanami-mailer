source 'https://rubygems.org'
gemspec

unless ENV['TRAVIS']
  gem 'byebug',           require: false, platforms: :mri
  gem 'allocation_stats', require: false
  gem 'benchmark-ips',    require: false
end

gem 'hanami-utils', '2.0.0.alpha1', require: false, git: 'https://github.com/hanami/utils.git', branch: 'unstable'
gem 'haml'

gem 'hanami-devtools', require: false, git: 'https://github.com/hanami/devtools.git'
gem 'coveralls', require: false
