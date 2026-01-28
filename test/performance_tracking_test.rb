# frozen_string_literal: true

require_relative 'test_helper'

# PERFORMANCE TRACKING TEST
# Tests for Bug #4: Performance tracking disabled without Rails
#
# Problem: track_performance bails out if Rails not defined
# making performance_stats always empty in non-Rails contexts

class PerformanceTrackingTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test that performance stats work without Rails
  def test_performance_stats_work_without_rails
    # This test verifies that performance tracking works regardless of Rails

    Predicate.define(:test) do
      fast_predicate { |s| s[:value] == true }
      slow_predicate do |s|
        sleep(0.01)
        s[:value] == true
      end
    end

    predicates = Predicate.for(:test)
    state = { value: true }

    # Call predicates multiple times
    10.times { predicates.call(:fast_predicate, state) }
    5.times { predicates.call(:slow_predicate, state) }

    # Performance stats should be populated (BUG: currently empty without Rails)
    stats = predicates.performance_stats

    # BUG: These assertions will FAIL because stats is empty {}
    refute_empty stats, 'Performance stats should NOT be empty (BUG: currently is)'

    assert stats.key?(:fast_predicate),
           'Performance stats should include fast_predicate'
    assert stats.key?(:slow_predicate),
           'Performance stats should include slow_predicate'

    # Check fast_predicate stats
    fast_stats = stats[:fast_predicate]
    assert_equal 10, fast_stats[:calls],
                 'fast_predicate should have 10 calls recorded'
    assert fast_stats[:total_time] >= 0,
           'total_time should be recorded'
    assert fast_stats[:average_time] >= 0,
           'average_time should be calculated'

    # Check slow_predicate stats
    slow_stats = stats[:slow_predicate]
    assert_equal 5, slow_stats[:calls],
                 'slow_predicate should have 5 calls recorded'
    # Timing assertions can be flaky, just verify it's > 0
    assert (slow_stats[:total_time]).positive?,
           'slow_predicate should have some total time recorded'
  end

  # Test that stats track min and max times
  def test_stats_track_min_and_max_times
    call_count = 0

    Predicate.define(:test) do
      variable_time do |_s|
        # First call: 0ms, second call: 10ms, third call: 5ms
        sleep_times = [0, 0.01, 0.005]
        sleep(sleep_times[call_count % 3])
        call_count += 1
        true
      end
    end

    predicates = Predicate.for(:test)

    # Call 3 times with different durations
    3.times { predicates.call(:variable_time, {}) }

    stats = predicates.performance_stats[:variable_time]

    assert stats[:min_time] >= 0,
           'min_time should be >= 0'
    assert stats[:max_time] > stats[:min_time],
           'max_time should be greater than min_time'
    assert_equal 3, stats[:calls],
                 'Should have 3 calls recorded'
  end

  # Test that stats are separate for different predicates
  def test_stats_separate_per_predicate
    Predicate.define(:test) do
      predicate_a { |s| s[:value] }
      predicate_b { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Call predicate_a 5 times
    5.times { predicates.call(:predicate_a, { value: true }) }

    # Call predicate_b 10 times
    10.times { predicates.call(:predicate_b, { value: true }) }

    stats = predicates.performance_stats

    assert_equal 5, stats[:predicate_a][:calls],
                 'predicate_a should have 5 calls'
    assert_equal 10, stats[:predicate_b][:calls],
                 'predicate_b should have 10 calls'
  end

  # Test that clearing cache doesn't clear performance stats
  def test_clear_cache_preserves_performance_stats
    Predicate.define(:test) do
      counter { |s| s[:value] }
    end

    predicates = Predicate.for(:test)

    # Call and build up stats
    10.times { predicates.call(:counter, { value: 42 }) }

    stats_before = predicates.performance_stats[:counter][:calls]
    assert_equal 10, stats_before

    # Clear cache
    predicates.clear_cache!

    # Stats should still be there
    stats_after = predicates.performance_stats[:counter]
    assert_equal 10, stats_after[:calls],
                 'Performance stats should be preserved after cache clear'
  end
end
