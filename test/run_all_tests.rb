#!/usr/bin/env ruby
# frozen_string_literal: true

# TEST RUNNER
# Runs all Predicate library tests and provides summary
#
# @author Nauman Tariq
# @version 1.0.0

require 'English'
require_relative 'test_helper'

puts '🚀 Running Predicate Library Test Suite...'
puts '=' * 60

# Test files to run
test_files = [
  'core_test.rb',
  'dsl_test.rb',
  'combinators_test.rb'
]

total_runs = 0
total_assertions = 0
total_failures = 0
total_errors = 0
failed_files = []

test_files.each do |test_file|
  puts "\n📝 Running #{test_file}..."
  puts '-' * 40

  # Capture test output
  result = `ruby #{test_file} 2>&1`
  exit_code = $CHILD_STATUS.exitstatus

  puts result

  # Parse test results
  if result =~ /(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/
    runs = Regexp.last_match(1).to_i
    assertions = Regexp.last_match(2).to_i
    failures = Regexp.last_match(3).to_i
    errors = Regexp.last_match(4).to_i

    total_runs += runs
    total_assertions += assertions
    total_failures += failures
    total_errors += errors

    if exit_code != 0 || failures.positive? || errors.positive?
      failed_files << test_file
      puts "❌ #{test_file} FAILED"
    else
      puts "✅ #{test_file} PASSED"
    end
  else
    failed_files << test_file
    puts "❌ #{test_file} FAILED (could not parse results)"
  end
end

puts "\n#{'=' * 60}"
puts '📊 SUMMARY'
puts '=' * 60
puts "Total test files: #{test_files.length}"
puts "Total runs: #{total_runs}"
puts "Total assertions: #{total_assertions}"
puts "Total failures: #{total_failures}"
puts "Total errors: #{total_errors}"

if failed_files.empty?
  puts "\n🎉 ALL TESTS PASSED!"
  puts '✨ Predicate library is working correctly'
  exit 0
else
  puts "\n💥 SOME TESTS FAILED:"
  failed_files.each { |file| puts "  - #{file}" }
  exit 1
end
