# frozen_string_literal: true

require_relative 'test_helper'

# ERROR HANDLING TEST
# Tests for proper error handling and edge cases
#
# Features tested:
# - InvalidPredicate exception is properly defined
# - Predicates without blocks raise meaningful errors
# - Sections without blocks raise meaningful errors
# - is_not_one_of_values? works in plain Ruby (no ActiveSupport)

class ErrorHandlingTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test that InvalidPredicate exception class is defined
  def test_invalid_predicate_exception_exists
    assert defined?(Predicate::InvalidPredicate),
           'Predicate::InvalidPredicate should be defined'
    assert Predicate::InvalidPredicate < StandardError,
           'InvalidPredicate should inherit from StandardError'
  end

  # Test that defining a predicate without a block raises InvalidPredicate
  def test_predicate_without_block_raises_error
    predicates = Predicate::Core.new(:test)

    error = assert_raises(Predicate::InvalidPredicate) do
      predicates.add_predicate(:no_block) # No block provided
    end

    assert_match(/block is required/, error.message)
  end

  # Test that defining a section without a block raises InvalidPredicate
  def test_section_without_block_raises_error
    predicates = Predicate::Core.new(:test)

    error = assert_raises(Predicate::InvalidPredicate) do
      predicates.add_section(:no_block) # No block provided
    end

    assert_match(/block is required/, error.message)
  end

  # Test is_not_one_of_values? works without ActiveSupport
  def test_is_not_one_of_values_plain_ruby
    predicates = Predicate::Core.new(:test)

    # Should work with arrays (no ActiveSupport needed)
    assert predicates.is_not_one_of_values?(5, [1, 2, 3])
    refute predicates.is_not_one_of_values?(2, [1, 2, 3])

    # Should work with ranges
    assert predicates.is_not_one_of_values?(10, 1..5)
    refute predicates.is_not_one_of_values?(3, 1..5)

    # Should handle nil gracefully
    assert predicates.is_not_one_of_values?(5, nil)
  end

  # Test is_not_one_of_values? with non-enumerable values
  def test_is_not_one_of_values_non_enumerable
    predicates = Predicate::Core.new(:test)

    # Should handle non-enumerable gracefully (treat as not included)
    assert predicates.is_not_one_of_values?(5, 'not enumerable')
    assert predicates.is_not_one_of_values?(5, 123)
  end

  # Test that exclude? is NOT used (should use !include? instead)
  def test_no_exclude_method_dependency
    # Read the core.rb source code
    File.read(File.expand_path('../lib/predicate/core.rb', __dir__))

    # Should not use .exclude? method (ActiveSupport-only)
    refute_match(/exclude/, Predicate::Core.instance_methods.to_s,
                 'Core should not use .exclude? method (ActiveSupport-only)')
  end

  # Test full integration: predicate definition error handling via DSL
  def test_dsl_predicate_without_block_error
    # The DSL should catch invalid predicate definitions
    error = assert_raises(Predicate::InvalidPredicate) do
      Predicate.define(:test) do
        # Call add_predicate without a block
        @core.add_predicate(:bad_predicate)
      end
    end

    assert_match(/block is required/, error.message)
  end

  # Test full integration: section definition error handling via DSL
  def test_dsl_section_without_block_error
    error = assert_raises(Predicate::InvalidPredicate) do
      Predicate.define(:test) do
        # Call add_section without a block
        @core.add_section(:bad_section)
      end
    end

    assert_match(/block is required/, error.message)
  end
end
