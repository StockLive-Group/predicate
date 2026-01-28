# frozen_string_literal: true

require_relative 'test_helper'

# CACHE COLLISION TESTS
# Tests to detect and prevent cache key collisions
#
# ISSUE: Current implementation uses state.hash which can collide
# GOAL: Ensure different states always produce different cache keys
#
# @author Nauman Tariq
# @version 1.0.0

class CacheCollisionTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    @core = test_predicate_core(:test)
    @counter = 0
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test that cache keys are unique for different states
  def test_cache_keys_are_unique_for_different_states
    # Create a predicate that tracks how many times it's called
    @core.add_predicate(:tracking_predicate) do |s|
      @counter += 1
      s[:value] == 'test'
    end

    # Create two different states
    state1 = { value: 'test', other: 'data1' }
    state2 = { value: 'test', other: 'data2' }

    # Call with first state
    result1 = @core.call(:tracking_predicate, state1)
    assert result1
    assert_equal 1, @counter

    # Call with second state - should NOT use cache because state is different
    result2 = @core.call(:tracking_predicate, state2)
    assert result2

    # THIS SHOULD BE 2, but with hash collisions it might be 1 (cache hit)
    # This test will FAIL if cache keys collide
    assert_equal 2, @counter,
                 "Expected predicate to be called twice for different states, but it was called #{@counter} times (cache collision?)"
  end

  # Test that identical states use cache
  def test_identical_states_use_cache
    @core.add_predicate(:tracking_predicate) do |s|
      @counter += 1
      (s[:value]).positive?
    end

    state = { value: 5, name: 'test' }

    # First call
    @core.call(:tracking_predicate, state)
    assert_equal 1, @counter

    # Second call with identical state - should use cache
    @core.call(:tracking_predicate, state)
    assert_equal 1, @counter, 'Expected cache hit for identical state'
  end

  # Test that states with same keys but different values don't collide
  def test_same_keys_different_values_no_collision
    @core.add_predicate(:value_checker) do |s|
      @counter += 1
      s[:key1] == 'value1'
    end

    state1 = { key1: 'value1', key2: 'value2' }
    state2 = { key1: 'value1', key2: 'value3' } # Different value for key2

    result1 = @core.call(:value_checker, state1)
    assert result1
    assert_equal 1, @counter

    result2 = @core.call(:value_checker, state2)
    assert result2

    # Should be called twice - different states
    assert_equal 2, @counter, 'Cache collision detected: same keys with different values'
  end

  # Test that key order doesn't matter
  def test_key_order_produces_same_cache_key
    @core.add_predicate(:order_test) do |_s|
      @counter += 1
      true
    end

    state1 = { a: 1, b: 2, c: 3 }
    state2 = { c: 3, a: 1, b: 2 } # Same data, different order

    @core.call(:order_test, state1)
    assert_equal 1, @counter

    @core.call(:order_test, state2)
    # Should use cache - same data regardless of order
    assert_equal 1, @counter, 'Expected cache hit for same data in different order'
  end

  # Test potential hash collision scenario
  def test_potential_hash_collision_scenario
    @core.add_predicate(:collision_test) do |_s|
      @counter += 1
      true
    end

    # These states are different but might produce hash collisions
    # depending on Ruby's hash implementation
    states = [
      { a: 1, b: 2 },
      { a: 2, b: 1 },
      { c: 1, d: 2 },
      { x: 3, y: 0 }
    ]

    results = []
    states.each_with_index do |state, _idx|
      @core.call(:collision_test, state)
      results << @counter
    end

    # Each different state should increment the counter
    assert_equal [1, 2, 3, 4], results,
                 'Cache collision detected: different states returned cached results'
  end

  # Test with complex nested state
  def test_nested_state_uniqueness
    @core.add_predicate(:nested_test) do |_s|
      @counter += 1
      true
    end

    state1 = { user: { id: 1, name: 'Alice' }, status: 'active' }
    state2 = { user: { id: 1, name: 'Bob' }, status: 'active' }

    @core.call(:nested_test, state1)
    assert_equal 1, @counter

    @core.call(:nested_test, state2)
    # These are different states - should NOT use cache
    assert_equal 2, @counter, 'Nested state cache collision'
  end

  # Test with array values in state
  def test_array_state_uniqueness
    @core.add_predicate(:array_test) do |_s|
      @counter += 1
      true
    end

    state1 = { ids: [1, 2, 3], type: 'test' }
    state2 = { ids: [1, 2, 4], type: 'test' } # Different array

    @core.call(:array_test, state1)
    assert_equal 1, @counter

    @core.call(:array_test, state2)
    # Different arrays - should NOT use cache
    assert_equal 2, @counter, 'Array state cache collision'
  end

  # Test with nil values
  def test_nil_values_in_state
    @core.add_predicate(:nil_test) do |_s|
      @counter += 1
      true
    end

    state1 = { a: nil, b: 'test' }
    state2 = { a: 'test', b: nil }

    @core.call(:nil_test, state1)
    assert_equal 1, @counter

    @core.call(:nil_test, state2)
    # Different states - should NOT use cache
    assert_equal 2, @counter, 'Nil value cache collision'
  end

  # Test that cache key generation is deterministic
  def test_cache_key_deterministic
    @core.add_predicate(:deterministic_test) do |_s|
      @counter += 1
      true
    end

    state = { a: 1, b: 2, c: 3 }

    # Call multiple times and verify cache is used
    10.times do |i|
      @core.call(:deterministic_test, state)
      assert_equal 1, @counter, "Cache key should be deterministic (iteration #{i})"
    end
  end

  # Test cache stats show correct hit/miss ratios
  def test_cache_stats_accuracy
    @core.add_predicate(:stats_test) { |s| (s[:value]).positive? }

    state1 = { value: 5 }
    state2 = { value: 10 }

    # First call - cache miss
    @core.call(:stats_test, state1)

    # Second call same state - cache hit
    @core.call(:stats_test, state1)

    # Third call different state - cache miss
    @core.call(:stats_test, state2)

    # Fourth call second state again - cache hit
    @core.call(:stats_test, state2)

    stats = @core.cache_stats
    assert_equal 2, stats[:cache_hits], 'Expected 2 cache hits'
    assert_equal 2, stats[:cache_misses], 'Expected 2 cache misses'
    assert_equal 0.5, stats[:cache_hit_ratio], 'Expected 50% hit ratio'
  end

  # Stress test: Many different states should not collide
  def test_many_states_no_collision
    @core.add_predicate(:stress_test) do |_s|
      @counter += 1
      true
    end

    # Generate 100 different states
    states = 100.times.map do |i|
      { id: i, value: "value_#{i}", count: i * 2 }
    end

    states.each { |state| @core.call(:stress_test, state) }

    # Each state should have been executed (no cache hits)
    assert_equal 100, @counter,
                 "Expected 100 unique cache keys, but only #{@counter} predicates were executed (collision rate: #{100 - @counter}%)"
  end
end
