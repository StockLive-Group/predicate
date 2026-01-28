# frozen_string_literal: true

require_relative 'test_helper'

class PerformanceTest < Minitest::Test
  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
    Predicate::Performance.reset!
  end

  def teardown
    Predicate.clear_cache!
    Predicate::Performance.reset!
  end

  def test_track_records_execution_time
    Predicate::Performance.track(:test_pred, 0.1)
    stats = Predicate::Performance.stats(:test_pred)

    assert_equal 1, stats[:total_calls]
    assert_in_delta 0.1, stats[:total_time]
    assert_in_delta 0.1, stats[:avg_time]
  end

  def test_track_accumulates_stats
    Predicate::Performance.track(:test_pred, 0.1)
    Predicate::Performance.track(:test_pred, 0.3)
    stats = Predicate::Performance.stats(:test_pred)

    assert_equal 2, stats[:total_calls]
    assert_in_delta 0.4, stats[:total_time]
    assert_in_delta 0.2, stats[:avg_time]
  end

  def test_track_cache_hit
    Predicate::Performance.track_cache_hit(:test_pred)
    stats = Predicate::Performance.stats(:test_pred)

    assert_equal 1, stats[:cache_hits]
    assert_equal 0, stats[:cache_misses]
  end

  def test_track_cache_miss
    Predicate::Performance.track_cache_miss(:test_pred)
    stats = Predicate::Performance.stats(:test_pred)

    assert_equal 0, stats[:cache_hits]
    assert_equal 1, stats[:cache_misses]
  end

  def test_integration_with_core
    Predicate.define(:perf_test) do
      check { |s| s[:value] }
    end

    core = Predicate.for(:perf_test)

    # First call - cache miss
    core.call(:check, { value: true })
    stats = Predicate::Performance.stats(:check)
    assert_equal 1, stats[:cache_misses]
    assert_equal 0, stats[:cache_hits]
    assert_equal 1, stats[:total_calls]

    # Second call - cache hit
    core.call(:check, { value: true })
    stats = Predicate::Performance.stats(:check)
    assert_equal 1, stats[:cache_misses]
    assert_equal 1, stats[:cache_hits]
    # Note: track is called on both hit and miss in current implementation
    assert_equal 2, stats[:total_calls]
  end

  def test_thread_safety
    threads = 10.times.map do
      Thread.new do
        100.times do
          Predicate::Performance.track(:concurrent, 0.01)
          Predicate::Performance.track_cache_hit(:concurrent)
        end
      end
    end
    threads.each(&:join)

    stats = Predicate::Performance.stats(:concurrent)
    assert_equal 1000, stats[:total_calls]
    assert_equal 1000, stats[:cache_hits]
  end
end
