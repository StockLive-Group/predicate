# frozen_string_literal: true

require_relative 'test_helper'

# DSL TESTS
# Comprehensive tests for Predicate::DSL functionality
#
# @author Nauman Tariq
# @version 1.0.0

class DSLTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    @entity = :test_assessment
    Predicate.clear_cache!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test basic DSL functionality
  def test_define_predicates_with_dsl
    predicates = Predicate.define(@entity) do
      has_media { |s| is_present?(s[:media_attachment_ids]) }
      has_title { |s| is_present?(s[:title]) }
      wizard_complete { |s| has_media(s) && has_title(s) }
    end

    state = test_state(media_attachment_ids: [1, 2], title: 'Test Title')

    assert predicates.call(:has_media, state)
    assert predicates.call(:has_title, state)
    assert predicates.call(:wizard_complete, state)
  end

  def test_define_predicates_with_false_conditions
    predicates = Predicate.define(@entity) do
      has_media { |s| is_present?(s[:media_attachment_ids]) }
      has_title { |s| is_present?(s[:title]) }
    end

    state_no_media = test_state(media_attachment_ids: [], title: 'Test Title')
    state_no_title = test_state(media_attachment_ids: [1, 2], title: nil)

    refute predicates.call(:has_media, state_no_media)
    refute predicates.call(:has_title, state_no_title)
  end

  # Test section-based predicates
  def test_section_predicates
    predicates = Predicate.define(@entity) do
      section :media do
        has_images { |s| is_present?(s[:media_attachment_ids]) }
        has_minimum_count { |s| s[:media_attachment_ids].length >= 2 }
        media_complete { |s| has_images(s) && has_minimum_count(s) }
      end

      section :validation do
        required_fields { |s| is_present?(s[:name]) && is_present?(s[:email]) }
        valid_email { |s| matches?(s[:email], /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }
      end
    end

    media_state = test_state(media_attachment_ids: [1, 2, 3])
    validation_state = test_state(name: 'John Doe', email: 'john@example.com')

    assert predicates.call(:has_images, media_state)
    assert predicates.call(:has_minimum_count, media_state)
    assert predicates.call(:media_complete, media_state)

    assert predicates.call(:required_fields, validation_state)
    assert predicates.call(:valid_email, validation_state)
  end

  def test_section_predicates_with_false_conditions
    predicates = Predicate.define(@entity) do
      section :validation do
        required_fields { |s| is_present?(s[:name]) && is_present?(s[:email]) }
        valid_email { |s| matches?(s[:email], /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }
      end
    end

    incomplete_state = test_state(name: 'John Doe', email: nil)
    invalid_email_state = test_state(name: 'John Doe', email: 'invalid-email')

    refute predicates.call(:required_fields, incomplete_state)
    refute predicates.call(:valid_email, invalid_email_state)
  end

  # Test cross-predicate calling
  def test_cross_predicate_calling
    predicates = Predicate.define(@entity) do
      has_media { |s| is_present?(s[:media_attachment_ids]) }
      has_title { |s| is_present?(s[:title]) }
      has_description { |s| is_present?(s[:description]) }

      media_complete { |s| has_media(s) }
      content_complete { |s| has_title(s) && has_description(s) }
      wizard_complete { |s| media_complete(s) && content_complete(s) }
    end

    complete_state = test_state(
      media_attachment_ids: [1, 2],
      title: 'Test Title',
      description: 'Test Description'
    )

    incomplete_state = test_state(
      media_attachment_ids: [1, 2],
      title: 'Test Title',
      description: nil
    )

    assert predicates.call(:wizard_complete, complete_state)
    refute predicates.call(:wizard_complete, incomplete_state)
  end

  # Test helper method delegation
  def test_helper_method_delegation
    predicates = Predicate.define(@entity) do
      is_positive { |s| positive?(s[:value]) }
      is_negative { |s| negative?(s[:value]) }
      is_zero { |s| zero?(s[:value]) }
      has_elements { |s| has_elements?(s[:items]) }
      has_keys { |s| has_keys?(s[:metadata]) }
      min_length_check { |s| min_length?(s[:password], 8) }
      max_length_check { |s| max_length?(s[:title], 100) }
      in_range_check { |s| in_range?(s[:age], 18..65) }
      type_check { |s| is_type?(s[:value], String) }
      equal_check { |s| equal_to?(s[:status], 'active') }
    end

    test_cases = [
      { predicate: :is_positive, state: { value: 5 }, expected: true },
      { predicate: :is_positive, state: { value: -5 }, expected: false },
      { predicate: :is_negative, state: { value: -5 }, expected: true },
      { predicate: :is_negative, state: { value: 5 }, expected: false },
      { predicate: :is_zero, state: { value: 0 }, expected: true },
      { predicate: :is_zero, state: { value: 5 }, expected: false },
      { predicate: :has_elements, state: { items: [1, 2, 3] }, expected: true },
      { predicate: :has_elements, state: { items: [] }, expected: false },
      { predicate: :has_keys, state: { metadata: { a: 1, b: 2 } }, expected: true },
      { predicate: :has_keys, state: { metadata: {} }, expected: false },
      { predicate: :min_length_check, state: { password: 'password123' }, expected: true },
      { predicate: :min_length_check, state: { password: 'short' }, expected: false },
      { predicate: :max_length_check, state: { title: 'Short title' }, expected: true },
      { predicate: :max_length_check, state: { title: 'A' * 150 }, expected: false },
      { predicate: :in_range_check, state: { age: 25 }, expected: true },
      { predicate: :in_range_check, state: { age: 17 }, expected: false },
      { predicate: :type_check, state: { value: 'string' }, expected: true },
      { predicate: :type_check, state: { value: 123 }, expected: false },
      { predicate: :equal_check, state: { status: 'active' }, expected: true },
      { predicate: :equal_check, state: { status: 'inactive' }, expected: false }
    ]

    test_cases.each do |test_case|
      result = predicates.call(test_case[:predicate], test_case[:state])
      if test_case[:expected]
        assert result, "Expected #{test_case[:predicate]} to return true for #{test_case[:state]}"
      else
        refute result, "Expected #{test_case[:predicate]} to return false for #{test_case[:state]}"
      end
    end
  end

  # Test validation helpers
  def test_validation_helpers
    predicates = Predicate.define(@entity) do
      validates_presence_of(:name, :email)
      validates_format_of(:email, with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      validates_numericality_of(:age, greater_than: 0, less_than: 150)
      validates_length_of(:password, minimum: 8, maximum: 128)
    end

    valid_state = test_state(
      name: 'John Doe',
      email: 'john@example.com',
      age: 25,
      password: 'password123'
    )

    invalid_states = [
      test_state(name: nil, email: 'john@example.com'), # Missing name
      test_state(name: 'John Doe', email: 'invalid-email'), # Invalid email format
      test_state(name: 'John Doe', email: 'john@example.com', age: -5), # Invalid age
      test_state(name: 'John Doe', email: 'john@example.com', password: 'short') # Password too short
    ]

    # Valid state should pass all validations
    # FIXED: Remove ? suffix - Bug #1 fix means predicates are stored without ?
    # FIXED: Correct predicate names (valid_age not valid_age_range)
    assert predicates.call(:has_name, valid_state)
    assert predicates.call(:has_email, valid_state)
    assert predicates.call(:required_fields, valid_state)
    assert predicates.call(:valid_email_format, valid_state)
    assert predicates.call(:valid_age, valid_state) # FIXED: valid_age, not valid_age_range
    assert predicates.call(:valid_password_length, valid_state)

    # Invalid states should fail specific validations
    refute predicates.call(:has_name, invalid_states[0])
    refute predicates.call(:valid_email_format, invalid_states[1])
    refute predicates.call(:valid_age, invalid_states[2]) # FIXED: valid_age, not valid_age_range
    refute predicates.call(:valid_password_length, invalid_states[3])
  end

  # Test error handling in DSL
  def test_error_handling_in_dsl
    predicates = Predicate.define(@entity) do
      error_predicate { |_s| raise StandardError, 'Test error' }
      safe_predicate { |s| is_present?(s[:value]) }
    end

    state = test_state(value: 'test')

    # Error predicate should return false (handled gracefully)
    refute predicates.call(:error_predicate, state)

    # Safe predicate should work normally
    assert predicates.call(:safe_predicate, state)
  end

  # Test predicate registration with registry
  def test_predicate_registration_with_registry
    predicates = Predicate.define(@entity) do
      test_predicate { |s| is_present?(s[:value]) }
    end

    # Should be registered in global registry
    retrieved_predicates = Predicate.for(@entity)
    assert_equal predicates.object_id, retrieved_predicates.object_id

    state = test_state(value: 'test')
    assert retrieved_predicates.call(:test_predicate, state)
  end

  # Test complex predicate combinations
  def test_complex_predicate_combinations
    predicates = Predicate.define(@entity) do
      # Basic predicates
      has_media { |s| is_present?(s[:media_attachment_ids]) && !s[:media_attachment_ids].empty? }
      has_title { |s| is_present?(s[:title]) && min_length?(s[:title], 3) }
      has_description { |s| is_present?(s[:description]) && min_length?(s[:description], 10) }
      has_tags { |s| is_present?(s[:tags]) && has_elements?(s[:tags]) }

      # Intermediate predicates
      content_ready { |s| has_title(s) && has_description(s) }
      media_ready { |s| has_media(s) }
      metadata_ready { |s| has_tags(s) }

      # Final predicate
      publication_ready { |s| content_ready(s) && media_ready(s) && metadata_ready(s) }
    end

    complete_state = test_state(
      media_attachment_ids: [1, 2, 3],
      title: 'Complete Article Title',
      description: 'This is a complete description with enough content to pass validation.',
      tags: %w[ruby programming testing]
    )

    incomplete_states = [
      test_state(media_attachment_ids: [], title: 'Title', description: 'Short description',
                 tags: ['ruby']),
      test_state(media_attachment_ids: [1, 2], title: 'A',
                 description: 'This is a complete description.', tags: ['ruby']),
      test_state(media_attachment_ids: [1, 2], title: 'Title', description: 'Short',
                 tags: ['ruby']),
      test_state(media_attachment_ids: [1, 2], title: 'Title',
                 description: 'This is a complete description.', tags: [])
    ]

    # Complete state should pass all predicates
    assert predicates.call(:publication_ready, complete_state)

    # Incomplete states should fail
    incomplete_states.each_with_index do |state, index|
      refute predicates.call(:publication_ready, state),
             "Incomplete state #{index + 1} should fail publication_ready check"
    end
  end

  # Test performance with caching
  def test_performance_with_caching
    call_count = 0

    predicates = Predicate.define(@entity) do
      expensive_predicate do |s|
        call_count += 1
        is_present?(s[:value])
      end
    end

    state = test_state(value: 'test')

    # First call should execute the predicate
    assert predicates.call(:expensive_predicate, state)
    assert_equal 1, call_count

    # Second call should use cache (call count shouldn't increase)
    assert predicates.call(:expensive_predicate, state)
    assert_equal 1, call_count

    # Different state should execute again
    different_state = test_state(value: 'different')
    assert predicates.call(:expensive_predicate, different_state)
    assert_equal 2, call_count
  end
end
