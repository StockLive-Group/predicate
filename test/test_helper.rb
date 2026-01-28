# frozen_string_literal: true

# TEST HELPER
# Common test utilities and setup for Predicate library tests
#
# Features:
# ┌────────────────────────────────────────────────────────────────────────┐
# │ • Test data factories and helpers                                      │
# │ • Common assertion methods                                             │
# │ • Performance testing utilities                                        │
# │ • Mock and stub helpers                                                │
# │ • Test environment setup                                               │
# └────────────────────────────────────────────────────────────────────────┘
#
# @author Nauman Tariq
# @version 1.0.0

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/mock'
require 'minitest/benchmark'

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

# Require the library like a gem
require 'predicate'

module Predicate
  module Test
    # Test helper methods and utilities
    module Helper
      # Create a test state hash with common attributes
      # @param attributes [Hash] Additional attributes to merge
      # @return [Hash] Test state hash
      def test_state(attributes = {})
        {
          id: 1,
          name: 'Test Assessment',
          status: 'draft',
          media_attachment_ids: [1, 2, 3],
          title: 'Test Title',
          description: 'Test Description',
          created_at: Predicate::Util.now,
          updated_at: Predicate::Util.now
        }.merge(attributes)
      end

      # Create a test predicate core instance
      # @param entity [Symbol] The entity name
      # @return [Predicate::Core] Test predicate core
      def test_predicate_core(entity = :test)
        Predicate::Core.new(entity)
      end

      # Create a test registry instance
      # @return [Predicate::Registry] Test registry
      def test_registry
        Predicate::Registry.new
      end

      # Assert that a predicate returns true for given state
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param state [Hash] The state to test
      # @param message [String] Custom assertion message
      def assert_predicate_true(predicate, name, state, message = nil)
        result = predicate.call(name, state)
        assert result, message || "Expected predicate #{name} to return true for state #{state}"
      end

      # Assert that a predicate returns false for given state
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param state [Hash] The state to test
      # @param message [String] Custom assertion message
      def assert_predicate_false(predicate, name, state, message = nil)
        result = predicate.call(name, state)
        refute result, message || "Expected predicate #{name} to return false for state #{state}"
      end

      # Assert that a predicate exists
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param message [String] Custom assertion message
      def assert_predicate_exists(predicate, name, message = nil)
        assert predicate.predicate?(name), message || "Expected predicate #{name} to exist"
      end

      # Assert that a predicate doesn't exist
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param message [String] Custom assertion message
      def assert_predicate_not_exists(predicate, name, message = nil)
        refute predicate.predicate?(name), message || "Expected predicate #{name} to not exist"
      end

      # Assert that a section exists
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The section name
      # @param message [String] Custom assertion message
      def assert_section_exists(predicate, name, message = nil)
        assert predicate.has_section?(name), message || "Expected section #{name} to exist"
      end

      # Assert that a section doesn't exist
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The section name
      # @param message [String] Custom assertion message
      def assert_section_not_exists(predicate, name, message = nil)
        refute predicate.has_section?(name), message || "Expected section #{name} to not exist"
      end

      # Assert that a predicate is cached
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param state [Hash] The state that should be cached
      # @param message [String] Custom assertion message
      def assert_predicate_cached(predicate, name, state, message = nil)
        # Use the same cache key generation logic as Core
        cache_key = generate_cache_key(name, state)
        assert predicate.instance_variable_get(:@memoized_results).key?(cache_key),
               message || "Expected predicate #{name} to be cached for state #{state}"
      end

      # Assert that a predicate is not cached
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param state [Hash] The state that should not be cached
      # @param message [String] Custom assertion message
      def assert_predicate_not_cached(predicate, name, state, message = nil)
        # Use the same cache key generation logic as Core
        cache_key = generate_cache_key(name, state)
        refute predicate.instance_variable_get(:@memoized_results).key?(cache_key),
               message || "Expected predicate #{name} to not be cached for state #{state}"
      end

      # Generate cache key using same logic as Predicate::Core
      # @param name [Symbol] The predicate name
      # @param state [Hash] The state hash
      # @return [String] The cache key
      def generate_cache_key(name, state)
        require 'json'
        require 'digest'
        sorted_state = state.sort_by { |k, _v| k.to_s }.to_h
        state_json = JSON.generate(sorted_state)
        state_hash = Digest::SHA256.hexdigest(state_json)[0..15]
        "#{name}_#{state_hash}"
      rescue StandardError
        state_signature = state.sort_by { |k, _v| k.to_s }.hash
        "#{name}_#{state_signature}"
      end

      # Assert that performance stats exist for a predicate
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param message [String] Custom assertion message
      def assert_performance_stats_exist(predicate, name, message = nil)
        stats = predicate.performance_stats
        assert stats.key?(name), message || "Expected performance stats for predicate #{name}"
      end

      # Assert that performance stats don't exist for a predicate
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param message [String] Custom assertion message
      def assert_performance_stats_not_exist(predicate, name, message = nil)
        stats = predicate.performance_stats
        refute stats.key?(name), message || "Expected no performance stats for predicate #{name}"
      end

      # Assert that a predicate executes within a time limit
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param state [Hash] The state to test
      # @param max_time [Float] Maximum execution time in seconds
      # @param message [String] Custom assertion message
      def assert_predicate_execution_time(predicate, name, state, max_time, message = nil)
        start_time = Predicate::Util.now
        predicate.call(name, state)
        execution_time = Predicate::Util.now - start_time

        assert execution_time <= max_time,
               message || "Expected predicate #{name} to execute within #{max_time}s, took #{execution_time}s"
      end

      # Create a mock state that responds to common methods
      # @param attributes [Hash] Attributes to set
      # @return [Object] Mock state object
      def mock_state(attributes = {})
        state = Object.new
        attributes.each do |key, value|
          state.define_singleton_method(key) { value }
        end

        # Add common methods
        state.define_singleton_method(:present?) do |val|
          !val.nil? && !(val.respond_to?(:empty?) && val.empty?)
        end
        state.define_singleton_method(:blank?) do |val|
          val.nil? || (val.respond_to?(:empty?) && val.empty?)
        end
        state.define_singleton_method(:empty?) { |val| val.respond_to?(:empty?) && val.empty? }

        state
      end

      # Create a test predicate that always returns true
      # @return [Proc] Predicate that returns true
      def always_true_predicate
        ->(_state) { true }
      end

      # Create a test predicate that always returns false
      # @return [Proc] Predicate that returns false
      def always_false_predicate
        ->(_state) { false }
      end

      # Create a test predicate that raises an error
      # @param error_class [Class] The error class to raise
      # @param message [String] The error message
      # @return [Proc] Predicate that raises an error
      def error_predicate(error_class = StandardError, message = 'Test error')
        ->(_state) { raise error_class, message }
      end

      # Create a test predicate that returns different values based on state
      # @param key [Symbol] The state key to check
      # @param true_value [Object] The value that should return true
      # @return [Proc] Predicate that returns true/false based on state
      def conditional_predicate(key, true_value)
        ->(state) { state[key] == true_value }
      end

      # Benchmark a predicate execution
      # @param predicate [Predicate::Core] The predicate instance
      # @param name [Symbol] The predicate name
      # @param state [Hash] The state to test
      # @param iterations [Integer] Number of iterations to run
      # @return [Hash] Benchmark results
      def benchmark_predicate(predicate, name, state, iterations = 1000)
        times = []

        iterations.times do
          start_time = Predicate::Util.now
          predicate.call(name, state)
          times << (Predicate::Util.now - start_time)
        end

        {
          iterations: iterations,
          total_time: times.sum,
          average_time: times.sum / iterations,
          min_time: times.min,
          max_time: times.max,
          median_time: times.sort[iterations / 2]
        }
      end

      # Test data factories
      module Factories
        # Create test assessment state
        def assessment_state(attributes = {})
          test_state({
            media_attachment_ids: [1, 2, 3],
            title: 'Test Assessment',
            description: 'Test Description',
            status: 'draft',
            age_range_upper: 24,
            age_range_lower: 18,
            assessment_breed_group_ids: [1, 2],
            total_breed_hd: 100,
            headcount: 100
          }.merge(attributes))
        end

        # Create test sale state
        def sale_state(attributes = {})
          test_state({
            name: 'Test Sale',
            status: 'presale',
            starting_at: 1.day.from_now,
            ending_at: 2.days.from_now,
            is_published: true,
            nextlot_sale: false,
            agrinous_sale: true
          }.merge(attributes))
        end

        # Create test booking state
        def booking_state(attributes = {})
          test_state({
            name: 'Test Booking',
            status: 'pending',
            starting_at: 1.day.from_now,
            ending_at: 2.days.from_now,
            full_name: 'John Doe',
            full_location: 'Test Location',
            email: 'test@example.com',
            phone: '0412345678'
          }.merge(attributes))
        end
      end

      # Include factories
      include Factories

      # Assert that no exception is raised
      def assert_nothing_raised(message = nil)
        yield
        assert true, message || 'Expected no exception to be raised'
      rescue StandardError => e
        flunk "#{message || 'Expected no exception to be raised'}, but got #{e.class}: #{e.message}"
      end
    end
  end
end
