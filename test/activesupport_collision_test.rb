# frozen_string_literal: true

require_relative 'test_helper'

# ACTIVESUPPORT COLLISION TEST
# Tests for the fix where present? and blank? in Predicate::Validation
# conflicted with ActiveSupport's Object#present? (0 args) and Object#blank? (0 args).
# They were renamed to is_present? and is_blank? to avoid the collision.

class ActiveSupportCollisionTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
    @core = Predicate::Core.new(:collision_test)
  end

  def teardown
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  # ============================================================================
  # is_present? returns true for present values
  # ============================================================================

  def test_is_present_with_non_empty_string
    assert @core.is_present?('hello'), 'Non-empty string should be present'
  end

  def test_is_present_with_number
    assert @core.is_present?(42), 'Number should be present'
    assert @core.is_present?(0), 'Zero should be present (it is not nil or empty)'
    assert @core.is_present?(-1), 'Negative number should be present'
    assert @core.is_present?(3.14), 'Float should be present'
  end

  def test_is_present_with_non_empty_array
    assert @core.is_present?([1, 2, 3]), 'Non-empty array should be present'
    assert @core.is_present?([nil]), 'Array with nil element should be present (not empty)'
  end

  def test_is_present_with_non_empty_hash
    assert @core.is_present?({ a: 1 }), 'Non-empty hash should be present'
  end

  # ============================================================================
  # is_present? returns false for blank values
  # ============================================================================

  def test_is_present_false_for_nil
    refute @core.is_present?(nil), 'nil should not be present'
  end

  def test_is_present_false_for_empty_string
    refute @core.is_present?(''), 'Empty string should not be present'
  end

  def test_is_present_false_for_whitespace_only_string
    refute @core.is_present?('   '), 'Whitespace-only string should not be present'
    refute @core.is_present?("\t\n"), 'Tab and newline string should not be present'
  end

  def test_is_present_false_for_empty_array
    refute @core.is_present?([]), 'Empty array should not be present'
  end

  def test_is_present_false_for_empty_hash
    refute @core.is_present?({}), 'Empty hash should not be present'
  end

  # ============================================================================
  # is_blank? returns true for blank values
  # ============================================================================

  def test_is_blank_true_for_nil
    assert @core.is_blank?(nil), 'nil should be blank'
  end

  def test_is_blank_true_for_empty_string
    assert @core.is_blank?(''), 'Empty string should be blank'
  end

  def test_is_blank_true_for_whitespace_only_string
    assert @core.is_blank?('   '), 'Whitespace-only string should be blank'
    assert @core.is_blank?("\t\n"), 'Tab and newline string should be blank'
  end

  def test_is_blank_true_for_empty_array
    assert @core.is_blank?([]), 'Empty array should be blank'
  end

  def test_is_blank_true_for_empty_hash
    assert @core.is_blank?({}), 'Empty hash should be blank'
  end

  # ============================================================================
  # is_blank? returns false for present values
  # ============================================================================

  def test_is_blank_false_for_non_empty_string
    refute @core.is_blank?('hello'), 'Non-empty string should not be blank'
  end

  def test_is_blank_false_for_number
    refute @core.is_blank?(42), 'Number should not be blank'
    refute @core.is_blank?(0), 'Zero should not be blank'
  end

  def test_is_blank_false_for_non_empty_array
    refute @core.is_blank?([1, 2, 3]), 'Non-empty array should not be blank'
  end

  # ============================================================================
  # is_present? and is_blank? are inverses of each other
  # ============================================================================

  def test_is_present_and_is_blank_are_inverse
    test_values = [
      nil,
      '',
      '   ',
      'hello',
      42,
      0,
      [],
      [1, 2],
      {},
      { a: 1 },
      true,
      false
    ]

    test_values.each do |value|
      present = @core.is_present?(value)
      blank = @core.is_blank?(value)

      assert_equal present, !blank,
                   "is_present?(#{value.inspect}) = #{present} should be inverse of is_blank?(#{value.inspect}) = #{blank}"
    end
  end

  # ============================================================================
  # Helpers work inside predicate blocks defined via DSL (the actual bug scenario)
  # ============================================================================

  def test_is_present_and_is_blank_work_inside_dsl_predicate_blocks
    Predicate.define(:collision_test) do
      has_name { |s| is_present?(s[:name]) }
      missing_name { |s| is_blank?(s[:name]) }
    end

    predicates = Predicate.for(:collision_test)

    # Test with present name
    state_with_name = { name: 'John' }
    assert predicates.call(:has_name, state_with_name),
           'has_name should return true when name is present'
    refute predicates.call(:missing_name, state_with_name),
           'missing_name should return false when name is present'

    # Test with nil name
    state_nil_name = { name: nil }
    refute predicates.call(:has_name, state_nil_name),
           'has_name should return false when name is nil'
    assert predicates.call(:missing_name, state_nil_name),
           'missing_name should return true when name is nil'

    # Test with empty string name
    state_empty_name = { name: '' }
    refute predicates.call(:has_name, state_empty_name),
           'has_name should return false when name is empty string'
    assert predicates.call(:missing_name, state_empty_name),
           'missing_name should return true when name is empty string'

    # Test with whitespace-only name
    state_whitespace_name = { name: '   ' }
    refute predicates.call(:has_name, state_whitespace_name),
           'has_name should return false when name is whitespace-only'
    assert predicates.call(:missing_name, state_whitespace_name),
           'missing_name should return true when name is whitespace-only'
  end

  def test_is_present_and_is_blank_work_in_section_dsl_blocks
    Predicate.define(:collision_section_test) do
      section :presence do
        has_email { |s| is_present?(s[:email]) }
        missing_email { |s| is_blank?(s[:email]) }
      end
    end

    predicates = Predicate.for(:collision_section_test)

    state_with_email = { email: 'test@example.com' }
    assert predicates.call_section(:presence, :has_email, state_with_email),
           'Section predicate has_email should return true when email is present'
    refute predicates.call_section(:presence, :missing_email, state_with_email),
           'Section predicate missing_email should return false when email is present'

    state_without_email = { email: nil }
    refute predicates.call_section(:presence, :has_email, state_without_email),
           'Section predicate has_email should return false when email is nil'
    assert predicates.call_section(:presence, :missing_email, state_without_email),
           'Section predicate missing_email should return true when email is nil'
  end

  # ============================================================================
  # Simulate ActiveSupport collision scenario
  # ============================================================================

  def test_is_present_still_works_when_object_has_zero_arg_present
    # Simulate ActiveSupport by defining Object#present? with 0 args
    # (if not already defined by ActiveSupport)
    already_defined = Object.method_defined?(:present?)

    unless already_defined
      Object.define_method(:present?) { !nil? && !(respond_to?(:empty?) && empty?) }
    end

    begin
      # is_present? should still work correctly since it takes 1 argument
      # (unlike the zero-arg Object#present? from ActiveSupport)
      assert @core.is_present?('hello'),
             'is_present? should work even when Object#present? is defined'
      refute @core.is_present?(nil),
             'is_present?(nil) should return false even when Object#present? is defined'
      refute @core.is_present?(''),
             'is_present?("") should return false even when Object#present? is defined'

      assert @core.is_blank?(nil),
             'is_blank? should work even when Object#blank? might be defined'
      refute @core.is_blank?('hello'),
             'is_blank?("hello") should return false even when Object#blank? might be defined'

      # Also verify it works inside DSL blocks during the collision
      Predicate.clear_registry!
      Predicate.define(:as_collision_sim) do
        has_value { |s| is_present?(s[:value]) }
        no_value { |s| is_blank?(s[:value]) }
      end

      predicates = Predicate.for(:as_collision_sim)
      assert predicates.call(:has_value, { value: 'test' }),
             'DSL-defined is_present? should work during ActiveSupport collision'
      assert predicates.call(:no_value, { value: nil }),
             'DSL-defined is_blank? should work during ActiveSupport collision'
    ensure
      # Clean up: remove the monkey-patched method if we added it
      Object.remove_method(:present?) unless already_defined
    end
  end

  def test_is_blank_still_works_when_object_has_zero_arg_blank
    # Simulate ActiveSupport's Object#blank? with 0 args
    already_defined = Object.method_defined?(:blank?)

    unless already_defined
      Object.define_method(:blank?) { nil? || (respond_to?(:empty?) && empty?) }
    end

    begin
      # is_blank? should still work correctly since it takes 1 argument
      assert @core.is_blank?(nil),
             'is_blank? should work even when Object#blank? is defined'
      assert @core.is_blank?(''),
             'is_blank?("") should work even when Object#blank? is defined'
      refute @core.is_blank?('hello'),
             'is_blank?("hello") should return false even when Object#blank? is defined'
    ensure
      # Clean up
      Object.remove_method(:blank?) unless already_defined
    end
  end

  # ============================================================================
  # Verify the renamed methods exist on Core (via Validation module)
  # ============================================================================

  def test_core_responds_to_is_present
    assert @core.respond_to?(:is_present?), 'Core should respond to is_present?'
  end

  def test_core_responds_to_is_blank
    assert @core.respond_to?(:is_blank?), 'Core should respond to is_blank?'
  end
end
