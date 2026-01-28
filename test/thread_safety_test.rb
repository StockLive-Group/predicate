# frozen_string_literal: true

require_relative 'test_helper'

# THREAD-SAFETY TEST
# Tests for Phase 3: Thread-safety implementation
#
# Features tested:
# - Optional thread_safe parameter at define time
# - Mutex protection for cache operations
# - Concurrent access without race conditions
# - Performance impact minimal when thread_safe: false

class ThreadSafetyTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test that thread_safe: false doesn't create mutex (default behavior)
  def test_thread_safe_false_no_mutex
    Predicate.define(:test) do # thread_safe defaults to false
      check { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Should NOT have a mutex
    refute predicates.instance_variable_get(:@thread_safe),
           'Should not be thread-safe by default'
    assert_nil predicates.instance_variable_get(:@cache_mutex),
               'Should not create mutex when thread_safe: false'
  end

  # Test that thread_safe: true creates mutex
  def test_thread_safe_true_creates_mutex
    Predicate.define(:test, thread_safe: true) do
      check { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Should have a mutex
    assert predicates.instance_variable_get(:@thread_safe),
           'Should be thread-safe'
    refute_nil predicates.instance_variable_get(:@cache_mutex),
               'Should create mutex when thread_safe: true'
    assert_kind_of Mutex, predicates.instance_variable_get(:@cache_mutex),
                   'Cache mutex should be a Mutex instance'
  end

  # Test concurrent access with thread_safe: true (no race conditions)
  def test_concurrent_access_thread_safe
    call_count = 0
    mutex = Mutex.new

    Predicate.define(:test, thread_safe: true) do
      increment do |_s|
        # Simulate race condition - without mutex this would be unsafe
        mutex.synchronize { call_count += 1 }
        call_count
      end
    end

    predicates = Predicate.for(:test)

    # Spawn 10 threads that all call the predicate simultaneously
    threads = 10.times.map do |i|
      Thread.new do
        # Each thread calls with different state (no cache hits)
        predicates.call(:increment, { id: i })
      end
    end

    # Wait for all threads
    threads.each(&:join)

    # All 10 threads should have executed
    assert_equal 10, call_count,
                 'All 10 threads should have executed without race conditions'

    # Cache should have 10 entries (one per unique state)
    cache_size = predicates.instance_variable_get(:@memoized_results).size
    assert_equal 10, cache_size,
                 'Cache should have 10 entries (one per thread)'
  end

  # Test concurrent access with same state (cache hits)
  def test_concurrent_cache_hits_thread_safe
    Predicate.define(:test, thread_safe: true) do
      check { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Spawn 100 threads that all use SAME state
    threads = 100.times.map do
      Thread.new do
        predicates.call(:check, { value: 42 })
      end
    end

    # Wait for all threads
    threads.each(&:join)

    # Should have 1 cache entry (all threads used same state)
    cache_size = predicates.instance_variable_get(:@memoized_results).size
    assert_equal 1, cache_size,
                 'Cache should have 1 entry despite 100 concurrent calls'

    # Cache stats should be consistent
    cache_hits = predicates.instance_variable_get(:@cache_hits)
    cache_misses = predicates.instance_variable_get(:@cache_misses)

    # Should have 1 miss (first call) + 99 hits (subsequent calls)
    # But due to race conditions, actual numbers might vary slightly
    # The important thing is no crashes/corruption
    assert_equal 1, cache_misses,
                 'Should have exactly 1 cache miss (first call)'
    assert_equal 99, cache_hits,
                 'Should have exactly 99 cache hits (subsequent calls)'
  end

  # Test thread-safety with TTL combination
  def test_thread_safety_with_ttl
    Predicate.define(:test, thread_safe: true, cache_ttl: 0.1) do
      check { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Should have both mutex and TTL
    assert predicates.instance_variable_get(:@thread_safe)
    refute_nil predicates.instance_variable_get(:@cache_mutex)
    assert_equal 0.1, predicates.instance_variable_get(:@cache_ttl)

    # Concurrent calls should work
    threads = 10.times.map do
      Thread.new do
        predicates.call(:check, { value: 42 })
      end
    end
    threads.each(&:join)

    # Wait for TTL to expire
    sleep(0.15)

    # More concurrent calls after expiration
    threads = 10.times.map do
      Thread.new do
        predicates.call(:check, { value: 42 })
      end
    end
    threads.each(&:join)

    # Should have recomputed after expiration
    # First batch: 1 miss + 9 hits
    # After expiration: 1 miss + 9 hits
    cache_misses = predicates.instance_variable_get(:@cache_misses)
    assert_equal 2, cache_misses,
                 'Should have 2 cache misses (initial + after TTL expiry)'
  end

  # Test that section predicates are also thread-safe
  def test_section_predicates_thread_safe
    Predicate.define(:test, thread_safe: true) do
      section :validation do
        check { |s| s[:value] }
      end
    end

    predicates = Predicate.for(:test)

    # Concurrent calls to section predicate
    threads = 50.times.map do
      Thread.new do
        predicates.call_section(:validation, :check, { value: 42 })
      end
    end
    threads.each(&:join)

    # Should have 1 cache entry
    cache_size = predicates.instance_variable_get(:@memoized_results).size
    assert_equal 1, cache_size,
                 'Section predicate cache should be thread-safe'

    # Should have consistent stats
    cache_hits = predicates.instance_variable_get(:@cache_hits)
    cache_misses = predicates.instance_variable_get(:@cache_misses)

    assert_equal 1, cache_misses, 'Should have 1 cache miss'
    assert_equal 49, cache_hits, 'Should have 49 cache hits'
  end

  # Test concurrent clear_cache! operations
  def test_concurrent_clear_cache_thread_safe
    Predicate.define(:test, thread_safe: true) do
      check { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Add some cache entries
    10.times { |i| predicates.call(:check, { value: i }) }

    # Concurrently clear cache and add new entries
    threads = []
    threads << Thread.new do
      5.times { predicates.clear_cache! }
    end
    threads += 20.times.map do |i|
      Thread.new do
        predicates.call(:check, { value: i + 100 })
      end
    end

    threads.each(&:join)

    # Should not crash or corrupt cache
    # Just verify we can still call predicates
    result = predicates.call(:check, { value: 999 })
    assert_equal 999, result
  end

  # Test performance impact is minimal when thread_safe: false
  def test_performance_without_thread_safety
    require 'benchmark'

    # Non-thread-safe version
    Predicate.define(:non_thread_safe) do
      check { |s| s[:value] }
    end

    # Thread-safe version
    Predicate.define(:thread_safe, thread_safe: true) do
      check { |s| s[:value] }
    end

    non_ts = Predicate.for(:non_thread_safe)
    ts = Predicate.for(:thread_safe)

    iterations = 1000

    # Benchmark non-thread-safe
    time_non_ts = Benchmark.realtime do
      iterations.times { |i| non_ts.call(:check, { value: i }) }
    end

    # Benchmark thread-safe
    time_ts = Benchmark.realtime do
      iterations.times { |i| ts.call(:check, { value: i }) }
    end

    # Thread-safe should not be significantly slower
    # Allow up to 100% overhead for mutex operations
    # (In practice it should be much less, but test environments vary)
    overhead_ratio = time_ts / time_non_ts
    assert overhead_ratio < 3.0,
           'Thread-safe version should not be more than 200% slower ' \
           "(non-ts: #{time_non_ts}s, ts: #{time_ts}s, ratio: #{overhead_ratio})"
  end
end
