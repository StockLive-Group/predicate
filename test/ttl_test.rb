# frozen_string_literal: true

require_relative 'test_helper'

# TTL TEST
# Tests for Phase 2: TTL (Time-To-Live) implementation
#
# Features tested:
# - Configurable TTL at define time
# - Cache expiration after TTL
# - Fresh computation after expiration
# - Automatic cleanup of expired entries

class TTLTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test cache without TTL persists forever
  def test_cache_without_ttl_persists
    Predicate.define(:test) do # No TTL specified
      counter { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Call with value 42
    result1 = predicates.call(:counter, { value: 42 })
    assert_equal 42, result1

    # Wait a bit
    sleep(0.1)

    # Call again - should still be cached (no expiration)
    result2 = predicates.call(:counter, { value: 42 })
    assert_equal 42, result2

    # Cache should have hit
    assert_equal 1, predicates.instance_variable_get(:@cache_hits),
                 'Cache should hit on second call (no TTL expiration)'
  end

  # Test cache WITH TTL expires after duration
  def test_cache_with_ttl_expires
    # Define with 0.1 second TTL
    Predicate.define(:test, cache_ttl: 0.1) do
      counter { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Call with value 42
    result1 = predicates.call(:counter, { value: 42 })
    assert_equal 42, result1

    # Call immediately - should hit cache
    result2 = predicates.call(:counter, { value: 42 })
    assert_equal 42, result2
    assert_equal 1, predicates.instance_variable_get(:@cache_hits),
                 'Should hit cache before TTL expires'

    # Wait for TTL to expire
    sleep(0.15)

    # Call again - cache should be expired, recompute
    result3 = predicates.call(:counter, { value: 42 })
    assert_equal 42, result3

    # Should be a cache miss (expired)
    assert_equal 2, predicates.instance_variable_get(:@cache_misses),
                 'Should miss cache after TTL expires (first call + expired call)'
  end

  # Test expired cache recomputes fresh value
  def test_expired_cache_recomputes_value
    call_count = 0

    Predicate.define(:test, cache_ttl: 0.1) do
      increment do |_s|
        call_count += 1
        call_count
      end
    end

    predicates = Predicate.for(:test)

    # First call
    result1 = predicates.call(:increment, {})
    assert_equal 1, result1, 'First call should increment to 1'

    # Second call (cached)
    result2 = predicates.call(:increment, {})
    assert_equal 1, result2, 'Second call should return cached value (still 1)'

    # Wait for expiration
    sleep(0.15)

    # Third call (expired, recomputes)
    result3 = predicates.call(:increment, {})
    assert_equal 2, result3, 'Third call should recompute (increment to 2)'
  end

  # Test TTL cleans old entries periodically
  def test_ttl_cleans_expired_entries
    Predicate.define(:test, cache_ttl: 0.1) do
      check { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Add many cache entries
    10.times do |i|
      predicates.call(:check, { value: i })
    end

    # Cache should have 10 entries
    cache_size_before = predicates.instance_variable_get(:@memoized_results).size
    assert_equal 10, cache_size_before

    # Wait for all to expire
    sleep(0.15)

    # Trigger cleanup by making a new call
    # (cleanup happens periodically, e.g., every 100 writes)
    100.times do |i|
      predicates.call(:check, { value: i + 100 })
    end

    # Old entries should be cleaned up
    cache = predicates.instance_variable_get(:@memoized_results)

    # Not all old entries will necessarily be gone,
    # but size should be reasonable (not 110)
    assert cache.size < 110,
           "Old expired entries should be cleaned up, cache size: #{cache.size}"
  end

  # Test different TTLs for different entities
  def test_different_ttls_per_entity
    # Short TTL
    Predicate.define(:short_ttl, cache_ttl: 0.05) do
      check { |s| s[:value] }
    end

    # Long TTL
    Predicate.define(:long_ttl, cache_ttl: 0.5) do
      check { |s| s[:value] }
    end

    short = Predicate.for(:short_ttl)
    long = Predicate.for(:long_ttl)

    # Call both
    short.call(:check, { value: 1 })
    long.call(:check, { value: 1 })

    # Wait 0.1 seconds (short TTL expired, long TTL still valid)
    sleep(0.1)

    # Call again
    short.call(:check, { value: 1 })
    long.call(:check, { value: 1 })

    # Short should have cache miss (expired)
    assert_equal 2, short.instance_variable_get(:@cache_misses),
                 'Short TTL should have 2 misses (initial + expired)'

    # Long should have cache hit (still valid)
    assert_equal 1, long.instance_variable_get(:@cache_hits),
                 'Long TTL should have 1 hit (still cached)'
  end

  # Test that cache_valid? method works correctly
  def test_cache_valid_method
    Predicate.define(:test, cache_ttl: 0.1) do
      check { |_s| true }
    end

    predicates = Predicate.for(:test)

    # Make a call to create cache entry
    predicates.call(:check, {})

    # Get cache key
    cache_key = predicates.send(:create_cache_key, :check, {})

    # Should be valid immediately
    assert predicates.send(:cache_valid?, cache_key),
           'Cache should be valid immediately after creation'

    # Wait for expiration
    sleep(0.15)

    # Should be invalid after TTL
    refute predicates.send(:cache_valid?, cache_key),
           'Cache should be invalid after TTL expires'
  end

  # Test TTL works with section predicates too
  def test_ttl_works_with_section_predicates
    Predicate.define(:test, cache_ttl: 0.1) do
      section :validation do
        check { |s| s[:value] }
      end
    end

    predicates = Predicate.for(:test)

    # Call section predicate
    result1 = predicates.call_section(:validation, :check, { value: 42 })
    assert_equal 42, result1

    # Call again - cached
    predicates.call_section(:validation, :check, { value: 42 })
    assert_equal 1, predicates.instance_variable_get(:@cache_hits)

    # Wait for expiration
    sleep(0.15)

    # Call again - expired
    predicates.call_section(:validation, :check, { value: 42 })
    assert_equal 2, predicates.instance_variable_get(:@cache_misses),
                 'Section predicate cache should also respect TTL'
  end
end
