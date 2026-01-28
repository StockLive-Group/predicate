# frozen_string_literal: true

require_relative 'test_helper'

# SECTION CACHE GUARDRAILS TEST
# Tests for Bug #6: Section caching bypasses guardrails
#
# Problem: call_section writes directly to cache without:
# - Cache hit/miss tracking
# - Size limit enforcement
# - Deterministic cache keys (uses state.hash - collision-prone!)
# - LRU eviction

class SectionCacheGuardrailsTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test that section predicates track cache hits/misses
  def test_section_predicates_track_cache_stats
    Predicate.define(:test) do
      section :validation do
        has_title { |s| present?(s[:title]) }
      end
    end

    predicates = Predicate.for(:test)

    # First call - should be cache miss
    predicates.call_section(:validation, :has_title, { title: 'Test' })

    # Second call with SAME state - should be cache hit
    predicates.call_section(:validation, :has_title, { title: 'Test' })

    # BUG: Section calls don't update @cache_hits / @cache_misses
    # So these will be 0
    cache_hits = predicates.instance_variable_get(:@cache_hits)
    cache_misses = predicates.instance_variable_get(:@cache_misses)

    assert cache_misses >= 1, 'Should have at least 1 cache miss (first call)'
    assert cache_hits >= 1, 'Should have at least 1 cache hit (second call)'
  end

  # Test that section cache uses deterministic keys (not state.hash)
  def test_section_cache_uses_deterministic_keys
    Predicate.define(:test) do
      section :validation do
        check { |s| s[:value] }
      end
    end

    predicates = Predicate.for(:test)

    # Create two states that might have same hash (collision)
    state1 = { value: 42, a: 1, b: 2 }
    state2 = { value: 99, c: 3, d: 4 }

    result1 = predicates.call_section(:validation, :check, state1)
    result2 = predicates.call_section(:validation, :check, state2)

    # Results should be different (42 != 99)
    assert_equal 42, result1
    assert_equal 99, result2

    # Call again - should get cached results
    cached1 = predicates.call_section(:validation, :check, state1)
    cached2 = predicates.call_section(:validation, :check, state2)

    assert_equal 42, cached1, 'Should get correct cached result for state1'
    assert_equal 99, cached2, 'Should get correct cached result for state2'
  end

  # Test that section cache respects size limit
  def test_section_cache_respects_size_limit
    Predicate.define(:test) do
      section :validation do
        check { |s| s[:value] }
      end
    end

    predicates = Predicate.for(:test)

    # Get the cache size limit
    cache_limit = predicates.instance_variable_get(:@cache_size_limit)
    assert_equal 1000, cache_limit, 'Cache limit should be 1000'

    # Fill cache beyond limit with section predicates
    # BUG: Section cache ignores size limit
    (cache_limit + 100).times do |i|
      predicates.call_section(:validation, :check, { value: i })
    end

    # Check cache size
    cache = predicates.instance_variable_get(:@memoized_results)
    cache_size = cache.size

    # Should not exceed limit (or be close to it with LRU eviction)
    assert cache_size <= cache_limit + 10,
           "Cache size #{cache_size} should not greatly exceed limit #{cache_limit}"
  end

  # Test that section predicates appear in performance stats
  def test_section_predicates_in_performance_stats
    Predicate.define(:test) do
      section :validation do
        has_title { |s| present?(s[:title]) }
      end
    end

    predicates = Predicate.for(:test)

    # Call section predicate multiple times
    5.times { predicates.call_section(:validation, :has_title, { title: 'Test' }) }

    # Performance stats should include section predicates
    stats = predicates.performance_stats

    # Section predicates should be tracked as "section_name_predicate_name"
    assert stats.key?(:validation_has_title),
           'Performance stats should include section predicates'

    section_stats = stats[:validation_has_title]
    assert_equal 5, section_stats[:calls],
                 'Should track number of calls to section predicate'
  end

  # Test that mixing regular and section predicates both use same guardrails
  def test_regular_and_section_predicates_use_same_cache_system
    Predicate.define(:test) do
      # Regular predicate
      regular_pred { |s| s[:value] }

      section :validation do
        section_pred { |s| s[:value] }
      end
    end

    predicates = Predicate.for(:test)

    # Call both types
    predicates.call(:regular_pred, { value: 1 })
    predicates.call_section(:validation, :section_pred, { value: 2 })

    # Both should contribute to same cache hit/miss counters
    predicates.instance_variable_get(:@cache_hits)
    cache_misses = predicates.instance_variable_get(:@cache_misses)

    # Should have 2 cache misses (one for each first call)
    assert_equal 2, cache_misses, 'Should have 2 cache misses'

    # Call again - both should hit cache
    predicates.call(:regular_pred, { value: 1 })
    predicates.call_section(:validation, :section_pred, { value: 2 })

    cache_hits_after = predicates.instance_variable_get(:@cache_hits)
    assert_equal 2, cache_hits_after, 'Should have 2 cache hits after second calls'
  end
end
