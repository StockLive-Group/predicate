# frozen_string_literal: true

require_relative 'test_helper'

# CORE ENGINE TESTS
# Comprehensive tests for Predicate::Core functionality
#
# @author Nauman Tariq
# @version 1.0.0

class CoreTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    @core = test_predicate_core(:assessment)
    @state = test_state
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test basic predicate functionality
  def test_add_and_call_predicate
    @core.add_predicate(:has_media) { |s| @core.is_present?(s[:media_attachment_ids]) }

    assert_predicate_exists(@core, :has_media)
    assert_predicate_true(@core, :has_media, @state)
    assert_predicate_false(@core, :has_media, test_state(media_attachment_ids: []))
  end

  def test_predicate_with_nil_state
    @core.add_predicate(:has_title) { |s| @core.is_present?(s[:title]) }

    assert_predicate_false(@core, :has_title, test_state(title: nil))
    assert_predicate_true(@core, :has_title, test_state(title: 'Test Title'))
  end

  def test_predicate_with_empty_array
    @core.add_predicate(:has_items) { |s| @core.is_present?(s[:items]) && !s[:items].empty? }

    assert_predicate_false(@core, :has_items, test_state(items: []))
    assert_predicate_false(@core, :has_items, test_state(items: nil))
    assert_predicate_true(@core, :has_items, test_state(items: [1, 2, 3]))
  end

  def test_predicate_with_complex_logic
    @core.add_predicate(:wizard_complete) do |s|
      @core.is_present?(s[:media_attachment_ids]) &&
        @core.is_present?(s[:title]) &&
        @core.is_present?(s[:description])
    end

    assert_predicate_true(@core, :wizard_complete, @state)
    assert_predicate_false(@core, :wizard_complete, test_state(title: nil))
    assert_predicate_false(@core, :wizard_complete, test_state(media_attachment_ids: []))
  end

  # Test caching functionality
  def test_predicate_caching
    call_count = 0
    @core.add_predicate(:expensive_predicate) do |s|
      call_count += 1
      (s[:value]).positive?
    end

    state = test_state(value: 5)

    # First call should execute the predicate
    assert_predicate_true(@core, :expensive_predicate, state)
    assert_equal 1, call_count

    # Second call should use cache
    assert_predicate_true(@core, :expensive_predicate, state)
    assert_equal 1, call_count # Should still be 1 due to caching
  end

  def test_cache_invalidation_on_predicate_change
    @core.add_predicate(:test_predicate) { |s| s[:value] == 1 }

    state = test_state(value: 1)
    assert_predicate_true(@core, :test_predicate, state)

    # Add new predicate should clear cache
    @core.add_predicate(:another_predicate) { |s| s[:value] == 2 }

    # Cache should be cleared, so we need to call again
    assert_predicate_true(@core, :test_predicate, state)
  end

  def test_manual_cache_clear
    @core.add_predicate(:test_predicate) { |s| (s[:value]).positive? }

    state = test_state(value: 5)
    assert_predicate_true(@core, :test_predicate, state)

    @core.clear_cache!
    assert_predicate_not_cached(@core, :test_predicate, state)
  end

  # Test section predicates
  def test_section_predicates
    @core.add_section(:media) do |predicates|
      predicates[:has_media] = ->(s) { @core.is_present?(s[:media_attachment_ids]) }
      predicates[:has_minimum_images] = ->(s) { s[:media_attachment_ids].length >= 1 }
      predicates[:complete] = lambda { |s|
        predicates[:has_media].call(s) && predicates[:has_minimum_images].call(s)
      }
    end

    assert_section_exists(@core, :media)
    assert_predicate_true(@core, :has_media, @state)
    assert_predicate_true(@core, :has_minimum_images, @state)
    assert_predicate_true(@core, :complete, @state)
  end

  def test_call_section_predicate
    @core.add_section(:age) do |predicates|
      predicates[:has_age_range] = lambda { |s|
        @core.is_present?(s[:age_range_upper]) && @core.is_present?(s[:age_range_lower])
      }
      predicates[:age_range_valid] = lambda { |s|
        s[:age_range_upper] > s[:age_range_lower]
      }
    end

    state_with_age = test_state(age_range_upper: 24, age_range_lower: 18)
    assert_predicate_true(@core, :has_age_range, state_with_age)
    assert_predicate_true(@core, :age_range_valid, state_with_age)

    invalid_state = test_state(age_range_upper: 18, age_range_lower: 24)
    assert_predicate_false(@core, :age_range_valid, invalid_state)
  end

  # Test error handling
  def test_predicate_error_handling
    @core.add_predicate(:error_predicate) { |_s| raise StandardError, 'Test error' }

    # Should return false and not raise error
    assert_predicate_false(@core, :error_predicate, @state)
  end

  def test_predicate_with_nil_predicate
    # Should return false for non-existent predicate
    assert_predicate_false(@core, :non_existent_predicate, @state)
  end

  # Test helper methods
  def test_present_helper
    assert @core.is_present?('test')
    assert @core.is_present?([1, 2, 3])
    refute @core.is_present?(nil)
    refute @core.is_present?('')
    refute @core.is_present?([])
  end

  def test_blank_helper
    assert @core.is_blank?(nil)
    assert @core.is_blank?('')
    assert @core.is_blank?([])
    refute @core.is_blank?('test')
    refute @core.is_blank?([1, 2, 3])
  end

  def test_not_helper
    assert @core.not?(false)
    assert @core.not?(nil)
    refute @core.not?(true)
    refute @core.not?('test')
  end

  def test_positive_helper
    assert @core.positive?(5)
    assert @core.positive?(0.1)
    refute @core.positive?(0)
    refute @core.positive?(-5)
    refute @core.positive?('test')
  end

  def test_negative_helper
    assert @core.negative?(-5)
    assert @core.negative?(-0.1)
    refute @core.negative?(0)
    refute @core.negative?(5)
    refute @core.negative?('test')
  end

  def test_zero_helper
    assert @core.zero?(0)
    assert @core.zero?(0.0)
    refute @core.zero?(5)
    refute @core.zero?(-5)
    refute @core.zero?('test')
  end

  def test_has_elements_helper
    assert @core.has_elements?([1, 2, 3])
    refute @core.has_elements?([])
    refute @core.has_elements?(nil)
    refute @core.has_elements?('test')
  end

  def test_has_keys_helper
    assert @core.has_keys?({ a: 1, b: 2 })
    refute @core.has_keys?({})
    refute @core.has_keys?(nil)
    refute @core.has_keys?('test')
  end

  def test_min_length_helper
    assert @core.min_length?('hello', 3)
    assert @core.min_length?([1, 2, 3], 2)
    refute @core.min_length?('hi', 3)
    refute @core.min_length?([1], 2)
    refute @core.min_length?(nil, 1)
  end

  def test_max_length_helper
    assert @core.max_length?('hi', 3)
    assert @core.max_length?([1, 2], 3)
    refute @core.max_length?('hello', 3)
    refute @core.max_length?([1, 2, 3], 2)
    refute @core.max_length?(nil, 1)
  end

  def test_min_value_helper
    assert @core.min_value?(5, 3)
    assert @core.min_value?(3, 3)
    refute @core.min_value?(2, 3)
    refute @core.min_value?('test', 3)
  end

  def test_max_value_helper
    assert @core.max_value?(2, 3)
    assert @core.max_value?(3, 3)
    refute @core.max_value?(5, 3)
    refute @core.max_value?('test', 3)
  end

  def test_in_range_helper
    assert @core.in_range?(5, 1..10)
    assert @core.in_range?(1, 1..10)
    assert @core.in_range?(10, 1..10)
    refute @core.in_range?(0, 1..10)
    refute @core.in_range?(11, 1..10)
    refute @core.in_range?('test', 1..10)
  end

  def test_matches_helper
    assert @core.matches?('hello@example.com', /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
    refute @core.matches?('invalid-email', /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
    refute @core.matches?(nil, /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end

  def test_is_type_helper
    assert @core.is_type?('test', String)
    assert @core.is_type?(5, Integer)
    assert @core.is_type?(5.0, Float)
    refute @core.is_type?('test', Integer)
    refute @core.is_type?(5, String)
  end

  def test_is_one_of_helper
    assert @core.is_one_of?('test', [String, Symbol])
    assert @core.is_one_of?(:test, [String, Symbol])
    refute @core.is_one_of?(5, [String, Symbol])
  end

  def test_is_one_of_values_helper
    assert @core.is_one_of_values?('test', %w[test example])
    assert @core.is_one_of_values?(5, [1, 5, 10])
    refute @core.is_one_of_values?('other', %w[test example])
  end

  def test_equal_to_helper
    assert @core.equal_to?('test', 'test')
    assert @core.equal_to?(5, 5)
    refute @core.equal_to?('test', 'other')
    refute @core.equal_to?(5, 6)
  end

  def test_not_equal_to_helper
    assert @core.not_equal_to?('test', 'other')
    assert @core.not_equal_to?(5, 6)
    refute @core.not_equal_to?('test', 'test')
    refute @core.not_equal_to?(5, 5)
  end

  def test_greater_than_helper
    assert @core.greater_than?(5, 3)
    refute @core.greater_than?(3, 5)
    refute @core.greater_than?(3, 3)
    refute @core.greater_than?('test', 3)
  end

  def test_less_than_helper
    assert @core.less_than?(3, 5)
    refute @core.less_than?(5, 3)
    refute @core.less_than?(3, 3)
    refute @core.less_than?('test', 3)
  end

  def test_greater_than_or_equal_to_helper
    assert @core.greater_than_or_equal_to?(5, 3)
    assert @core.greater_than_or_equal_to?(3, 3)
    refute @core.greater_than_or_equal_to?(3, 5)
    refute @core.greater_than_or_equal_to?('test', 3)
  end

  def test_less_than_or_equal_to_helper
    assert @core.less_than_or_equal_to?(3, 5)
    assert @core.less_than_or_equal_to?(3, 3)
    refute @core.less_than_or_equal_to?(5, 3)
    refute @core.less_than_or_equal_to?('test', 3)
  end

  # Test predicate names and sections
  def test_predicate_names
    @core.add_predicate(:predicate1) { |_s| true }
    @core.add_predicate(:predicate2) { |_s| false }

    names = @core.predicate_names
    assert_includes names, :predicate1
    assert_includes names, :predicate2
    assert_equal 2, names.size
  end

  def test_section_names
    @core.add_section(:section1) do |p| # Empty section
    end
    @core.add_section(:section2) do |p| # Empty section
    end

    names = @core.section_names
    assert_includes names, :section1
    assert_includes names, :section2
    assert_equal 2, names.size
  end

  def test_has_predicate
    @core.add_predicate(:test_predicate) { |_s| true }

    assert @core.predicate?(:test_predicate), 'Predicate should be registered'
    refute @core.predicate?(:non_existent)
  end

  def test_has_section
    @core.add_section(:test_section) do |p| # Empty section
    end

    assert @core.has_section?(:test_section)
    refute @core.has_section?(:non_existent)
  end

  # Test cache statistics
  def test_cache_stats
    @core.add_predicate(:test_predicate) { |s| (s[:value]).positive? }

    state = test_state(value: 5)
    @core.call(:test_predicate, state)

    stats = @core.cache_stats
    assert stats.key?(:cached_results)
    assert stats.key?(:predicates)
    assert stats.key?(:sections)
    assert_equal 1, stats[:predicates]
  end

  # Test performance statistics
  def test_performance_stats
    @core.add_predicate(:test_predicate) { |s| (s[:value]).positive? }

    state = test_state(value: 5)
    @core.call(:test_predicate, state)

    stats = @core.performance_stats
    assert stats.key?(:test_predicate)

    predicate_stats = stats[:test_predicate]
    assert predicate_stats.key?(:calls)
    assert predicate_stats.key?(:total_time)
    assert predicate_stats.key?(:average_time)
    assert_equal 1, predicate_stats[:calls]
  end

  # Test entity attribute
  def test_entity_attribute
    core = Predicate::Core.new(:test_entity)
    assert_equal :test_entity, core.entity
  end

  # Test predicates and sections attributes
  def test_predicates_and_sections_attributes
    @core.add_predicate(:test_predicate) { |_s| true }
    @core.add_section(:test_section) do |p| # Empty section
    end

    assert @core.predicates.key?(:test_predicate)
    assert @core.sections.key?(:test_section)
  end
end
