# frozen_string_literal: true

require 'rake/testtask'

# Default task: run all tests
task default: :test

# Main test task - runs all tests
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
  t.warning = false
end

# Individual test tasks for specific modules
namespace :test do
  desc 'Run core tests'
  Rake::TestTask.new(:core) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.test_files = ['test/core_test.rb']
    t.verbose = true
  end

  desc 'Run DSL tests'
  Rake::TestTask.new(:dsl) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.test_files = ['test/dsl_test.rb']
    t.verbose = true
  end

  desc 'Run combinator tests'
  Rake::TestTask.new(:combinators) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.test_files = ['test/combinators_test.rb']
    t.verbose = true
  end

  desc 'Run model integration tests'
  Rake::TestTask.new(:model) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.test_files = ['test/model_integration_test.rb']
    t.verbose = true
  end

  desc 'Run cache collision tests'
  Rake::TestTask.new(:cache) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.test_files = ['test/cache_collision_test.rb']
    t.verbose = true
  end

  desc 'Run TTL tests'
  Rake::TestTask.new(:ttl) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.test_files = ['test/ttl_test.rb']
    t.verbose = true
  end

  desc 'Run thread safety tests'
  Rake::TestTask.new(:thread_safety) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.test_files = ['test/thread_safety_test.rb']
    t.verbose = true
  end
end

desc 'Run tests with verbose output'
task :verbose do
  ENV['VERBOSE'] = 'true'
  Rake::Task[:test].invoke
end

desc 'Show library structure'
task :structure do
  puts "\n📁 Predicate Library Structure:"
  puts '=' * 70
  system("tree -I 'doc|docs' -L 3 || find . -type f -name '*.rb' | sort")
end

desc 'Clean test artifacts'
task :clean do
  require 'fileutils'
  FileUtils.rm_rf('coverage')
  FileUtils.rm_rf('tmp')
  puts 'Cleaned test artifacts'
end

desc 'Build gem'
task :build do
  system 'gem build predicate.gemspec'
end

desc 'Install gem locally'
task install: :build do
  system 'gem install predicate-*.gem'
end
