# frozen_string_literal: true

source 'https://rubygems.org'

# Specify Ruby version
ruby '>= 3.0.0'

# Load gemspec dependencies
gemspec

# Runtime dependencies
gem 'json' # Used for cache key generation

# Development and test dependencies
group :development, :test do
  gem 'minitest', '~> 5.0'
  gem 'rake', '~> 13.0'
end

# Optional: Pretty test output & Code quality
group :development do
  gem 'minitest-reporters', '~> 1.6', require: false
  gem 'rubocop', '~> 1.50', require: false
  gem 'rubocop-minitest', '~> 0.31', require: false
end

# Optional: Code coverage
group :test do
  gem 'simplecov', '~> 0.22', require: false
end
