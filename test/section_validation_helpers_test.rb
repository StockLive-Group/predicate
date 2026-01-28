# frozen_string_literal: true

require_relative 'test_helper'

# SECTION VALIDATION HELPERS TEST
# Tests for Bug #2: SectionBuilder can't use ValidationHelpers
#
# Problem: ValidationHelpers requires define_predicate method
# but SectionBuilder doesn't implement it = NotImplementedError

class SectionValidationHelpersTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test that validates_presence_of works inside sections
  def test_validates_presence_of_in_section
    # This should work but currently raises NotImplementedError
    Predicate.define(:test) do
      section :validation do
        validates_presence_of(:title, :description)
      end
    end

    predicates = Predicate.for(:test)

    # Should be able to call section predicates
    state_with_both = { title: 'Test', description: 'Desc' }
    assert predicates.call_section(:validation, :has_title, state_with_both),
           'Section predicate has_title should return true'

    state_without_desc = { title: 'Test', description: nil }
    refute predicates.call_section(:validation, :has_description, state_without_desc),
           'Section predicate has_description should return false'

    # Combined predicate
    assert predicates.call_section(:validation, :required_fields, state_with_both),
           'required_fields should return true when all present'
    refute predicates.call_section(:validation, :required_fields, state_without_desc),
           'required_fields should return false when description missing'
  end

  # Test validates_format_of in sections
  def test_validates_format_of_in_section
    Predicate.define(:test) do
      section :validation do
        validates_format_of(:email, with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
      end
    end

    predicates = Predicate.for(:test)

    valid_state = { email: 'test@example.com' }
    assert predicates.call_section(:validation, :valid_email_format, valid_state),
           'valid_email_format should return true for valid email'

    invalid_state = { email: 'invalid-email' }
    refute predicates.call_section(:validation, :valid_email_format, invalid_state),
           'valid_email_format should return false for invalid email'
  end

  # Test validates_length_of in sections
  def test_validates_length_of_in_section
    Predicate.define(:test) do
      section :validation do
        validates_length_of(:password, minimum: 8, maximum: 128)
      end
    end

    predicates = Predicate.for(:test)

    valid_state = { password: 'secure123' }
    assert predicates.call_section(:validation, :valid_password_length, valid_state),
           'valid_password_length should return true for valid length'

    too_short = { password: 'short' }
    refute predicates.call_section(:validation, :valid_password_length, too_short),
           'valid_password_length should return false for too short'

    too_long = { password: 'a' * 129 }
    refute predicates.call_section(:validation, :valid_password_length, too_long),
           'valid_password_length should return false for too long'
  end

  # Test validates_numericality_of in sections
  def test_validates_numericality_of_in_section
    Predicate.define(:test) do
      section :validation do
        validates_numericality_of(:age, greater_than: 0, less_than: 150)
      end
    end

    predicates = Predicate.for(:test)

    valid_state = { age: 25 }
    assert predicates.call_section(:validation, :valid_age, valid_state),
           'valid_age should return true for valid number'

    invalid_state = { age: 0 }
    refute predicates.call_section(:validation, :valid_age, invalid_state),
           'valid_age should return false for invalid number'

    too_high = { age: 200 }
    refute predicates.call_section(:validation, :valid_age, too_high),
           'valid_age should return false for number too high'
  end

  # Test mixing validation helpers with regular predicates in sections
  def test_mixing_validation_helpers_and_regular_predicates_in_section
    Predicate.define(:test) do
      section :user_validation do
        validates_presence_of(:username)
        validates_format_of(:email, with: /@/)

        # Regular predicate
        is_admin { |s| s[:role] == 'admin' }

        # Combined predicate using validation helpers
        valid_user { |s| has_username(s) && valid_email_format(s) }
      end
    end

    predicates = Predicate.for(:test)

    # Test validation helper predicates
    state = { username: 'john', email: 'john@example.com', role: 'user' }
    assert predicates.call_section(:user_validation, :has_username, state)
    assert predicates.call_section(:user_validation, :valid_email_format, state)

    # Test regular predicate
    refute predicates.call_section(:user_validation, :is_admin, state)

    # Test combined predicate
    assert predicates.call_section(:user_validation, :valid_user, state)
  end
end
