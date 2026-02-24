# frozen_string_literal: true

require_relative 'test_helper'

# HELPER METHODS TEST
# Tests for Core helper methods (is_present?, is_blank?, is_one_of_values?, etc.)
#
# Features tested:
# - All helpers work without ActiveSupport
# - Edge cases are handled gracefully
# - No dependencies on Rails-specific methods

class HelperMethodsTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
    @core = Predicate::Core.new(:test)
  end

  def teardown
    Predicate.clear_cache!
  end

  # ============================================================================
  # is_one_of_values? tests
  # ============================================================================

  def test_is_one_of_values_with_array
    assert @core.is_one_of_values?(1, [1, 2, 3])
    assert @core.is_one_of_values?('a', %w[a b c])
    refute @core.is_one_of_values?(4, [1, 2, 3])
  end

  def test_is_one_of_values_with_range
    assert @core.is_one_of_values?(5, 1..10)
    refute @core.is_one_of_values?(15, 1..10)
  end

  def test_is_one_of_values_with_set
    require 'set'
    set = Set.new([1, 2, 3])
    assert @core.is_one_of_values?(2, set)
    refute @core.is_one_of_values?(5, set)
  end

  def test_is_one_of_values_with_empty_array
    refute @core.is_one_of_values?(1, [])
  end

  # ============================================================================
  # is_not_one_of_values? tests (the fixed method)
  # ============================================================================

  def test_is_not_one_of_values_with_array
    assert @core.is_not_one_of_values?(5, [1, 2, 3])
    refute @core.is_not_one_of_values?(2, [1, 2, 3])
  end

  def test_is_not_one_of_values_with_range
    assert @core.is_not_one_of_values?(15, 1..10)
    refute @core.is_not_one_of_values?(5, 1..10)
  end

  def test_is_not_one_of_values_with_set
    require 'set'
    set = Set.new([1, 2, 3])
    assert @core.is_not_one_of_values?(5, set)
    refute @core.is_not_one_of_values?(2, set)
  end

  def test_is_not_one_of_values_with_nil
    # nil doesn't respond to :include?, so should return true
    assert @core.is_not_one_of_values?(5, nil)
  end

  def test_is_not_one_of_values_with_non_enumerable
    # String doesn't respond to :include? in the same way
    # Should return true (treat as not included)
    assert @core.is_not_one_of_values?(5, 'not enumerable')
    assert @core.is_not_one_of_values?(5, 123)
    assert @core.is_not_one_of_values?(5, Object.new)
  end

  def test_is_not_one_of_values_with_empty_array
    assert @core.is_not_one_of_values?(1, [])
  end

  # ============================================================================
  # is_present? and is_blank? tests
  # ============================================================================

  def test_present_with_values
    assert @core.is_present?('hello')
    assert @core.is_present?(123)
    assert @core.is_present?([1, 2, 3])
    assert @core.is_present?({ a: 1 })
  end

  def test_present_with_blank_values
    refute @core.is_present?(nil)
    refute @core.is_present?('')
    refute @core.is_present?('   ')
    refute @core.is_present?([])
    refute @core.is_present?({})
  end

  def test_blank_with_values
    refute @core.is_blank?('hello')
    refute @core.is_blank?(123)
    refute @core.is_blank?([1, 2, 3])
  end

  def test_blank_with_blank_values
    assert @core.is_blank?(nil)
    assert @core.is_blank?('')
    assert @core.is_blank?('   ')
    assert @core.is_blank?([])
    assert @core.is_blank?({})
  end

  # ============================================================================
  # Comparison helpers tests
  # ============================================================================

  def test_greater_than
    assert @core.greater_than?(10, 5)
    refute @core.greater_than?(5, 10)
    refute @core.greater_than?(5, 5)
  end

  def test_less_than
    assert @core.less_than?(5, 10)
    refute @core.less_than?(10, 5)
    refute @core.less_than?(5, 5)
  end

  def test_greater_than_or_equal_to
    assert @core.greater_than_or_equal_to?(10, 5)
    assert @core.greater_than_or_equal_to?(5, 5)
    refute @core.greater_than_or_equal_to?(5, 10)
  end

  def test_less_than_or_equal_to
    assert @core.less_than_or_equal_to?(5, 10)
    assert @core.less_than_or_equal_to?(5, 5)
    refute @core.less_than_or_equal_to?(10, 5)
  end

  def test_equal_to
    assert @core.equal_to?(5, 5)
    assert @core.equal_to?('hello', 'hello')
    refute @core.equal_to?(5, 10)
  end

  # ============================================================================
  # Pattern matching tests
  # ============================================================================

  def test_matches_with_regex
    assert @core.matches?('hello@example.com', /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
    refute @core.matches?('invalid-email', /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end

  def test_matches_with_string_pattern
    assert @core.matches?('hello world', 'hello')
    refute @core.matches?('goodbye', 'hello')
  end

  # ============================================================================
  # not? helper test
  # ============================================================================

  def test_not_helper
    assert @core.not?(false)
    refute @core.not?(true)
  end

  # ============================================================================
  # Integration: Use helpers in predicates
  # ============================================================================

  def test_helpers_in_predicate_definitions
    Predicate.define(:validation) do
      valid_age { |s| greater_than?(s[:age], 0) && less_than?(s[:age], 150) }
      valid_status { |s| is_one_of_values?(s[:status], %w[active pending inactive]) }
      invalid_status { |s| is_not_one_of_values?(s[:status], %w[deleted banned]) }
    end

    predicates = Predicate.for(:validation)

    assert predicates.call(:valid_age, { age: 25 })
    refute predicates.call(:valid_age, { age: 200 })

    assert predicates.call(:valid_status, { status: 'active' })
    refute predicates.call(:valid_status, { status: 'deleted' })

    assert predicates.call(:invalid_status, { status: 'active' })
    refute predicates.call(:invalid_status, { status: 'deleted' })
  end
end
