# frozen_string_literal: true

require 'bundler/gem_tasks' # build / install / release
require 'rake/testtask'

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

# ── the boundary check ────────────────────────────────────────────────────
#
# Every library file lives inside `module Predicate`. A file that does not is
# declaring something in the host's global namespace. The distribution loader
# (lib/predicate-rb.rb) is the one exception: it only requires the library.
desc 'Fail if a library file declares anything outside module Predicate'
task :boundary do
  problems = Dir['lib/**/*.rb'].reject { |file| file == 'lib/predicate-rb.rb' }
                               .reject { |file| File.read(file).include?('module Predicate') }
  if problems.any?
    problems.each { |file| warn "  #{file}: no `module Predicate`" }
    abort 'BOUNDARY FAILED — see above.'
  end
  puts 'boundary: clean — every library file is inside module Predicate'
end

desc 'Fail if a GitHub workflow file is not valid YAML'
task :workflows do
  require 'yaml'
  Dir['.github/workflows/*.yml'].each do |file|
    YAML.load_file(file)
    puts "workflow ok: #{file}"
  rescue StandardError => e
    abort "INVALID WORKFLOW #{file}: #{e.message}"
  end
end

# `workflows` is in the gate because a broken workflow fails at 0s with no test
# output — the local hook runs the suite, so it cannot catch a CI file that
# never starts.
task default: %i[boundary workflows test]
