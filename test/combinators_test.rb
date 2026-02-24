# frozen_string_literal: true

require_relative 'test_helper'

# COMBINATORS TESTS
# Comprehensive tests for Predicate::Combinators functionality
#
# @author Nauman Tariq
# @version 1.0.0

class CombinatorsTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    @entity = :test_combinators
    Predicate.clear_cache!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test ALL_OF combinator (logical AND)
  def test_all_of_combinator
    predicates = Predicate.define(@entity) do
      has_title { |s| is_present?(s[:title]) }
      has_description { |s| is_present?(s[:description]) }
      has_media { |s| is_present?(s[:media_attachment_ids]) }

      content_complete { |s| all_of(:has_title, :has_description).call(s) }
      all_complete { |s| all_of(:has_title, :has_description, :has_media).call(s) }
    end

    complete_state = test_state(
      title: 'Test Title',
      description: 'Test Description',
      media_attachment_ids: [1, 2, 3]
    )

    partial_state = test_state(
      title: 'Test Title',
      description: nil,
      media_attachment_ids: [1, 2, 3]
    )

    empty_state = test_state(title: nil, description: nil, media_attachment_ids: [])

    # Complete state should pass all combinations
    assert predicates.call(:content_complete, complete_state)
    assert predicates.call(:all_complete, complete_state)

    # Partial state should fail content_complete and all_complete
    refute predicates.call(:content_complete, partial_state)
    refute predicates.call(:all_complete, partial_state)

    # Empty state should fail everything
    refute predicates.call(:content_complete, empty_state)
    refute predicates.call(:all_complete, empty_state)
  end

  # Test ANY_OF combinator (logical OR)
  def test_any_of_combinator
    predicates = Predicate.define(@entity) do
      has_title { |s| is_present?(s[:title]) }
      has_description { |s| is_present?(s[:description]) }
      has_media { |s| is_present?(s[:media_attachment_ids]) }

      has_content { |s| any_of(:has_title, :has_description).call(s) }
      has_anything { |s| any_of(:has_title, :has_description, :has_media).call(s) }
    end

    title_only_state = test_state(title: 'Test Title', description: nil, media_attachment_ids: [])
    description_only_state = test_state(title: nil, description: 'Test Description',
                                        media_attachment_ids: [])
    media_only_state = test_state(title: nil, description: nil, media_attachment_ids: [1, 2])
    empty_state = test_state(title: nil, description: nil, media_attachment_ids: [])

    # States with any content should pass
    assert predicates.call(:has_content, title_only_state)
    assert predicates.call(:has_content, description_only_state)
    assert predicates.call(:has_anything, title_only_state)
    assert predicates.call(:has_anything, description_only_state)
    assert predicates.call(:has_anything, media_only_state)

    # Media-only should fail content check but pass anything check
    refute predicates.call(:has_content, media_only_state)
    assert predicates.call(:has_anything, media_only_state)

    # Empty state should fail everything
    refute predicates.call(:has_content, empty_state)
    refute predicates.call(:has_anything, empty_state)
  end

  # Test NONE_OF combinator (logical NOR)
  def test_none_of_combinator
    predicates = Predicate.define(@entity) do
      has_errors { |s| is_present?(s[:errors]) }
      is_invalid { |s| s[:valid] == false }
      is_expired { |s| s[:expired] == true }

      is_clean { |s| none_of(:has_errors, :is_invalid, :is_expired).call(s) }
    end

    clean_state = test_state(errors: [], valid: true, expired: false)
    error_state = test_state(errors: ['Error 1'], valid: true, expired: false)
    invalid_state = test_state(errors: [], valid: false, expired: false)
    expired_state = test_state(errors: [], valid: true, expired: true)
    multiple_issues_state = test_state(errors: ['Error 1'], valid: false, expired: true)

    # Clean state should pass
    assert predicates.call(:is_clean, clean_state)

    # States with any issues should fail
    refute predicates.call(:is_clean, error_state)
    refute predicates.call(:is_clean, invalid_state)
    refute predicates.call(:is_clean, expired_state)
    refute predicates.call(:is_clean, multiple_issues_state)
  end

  # Test NOT combinator (logical NOT)
  def test_not_combinator
    predicates = Predicate.define(@entity) do
      has_errors { |s| is_present?(s[:errors]) && !s[:errors].empty? }
      is_valid { |s| s[:valid] == true }

      no_errors { |s| negate(:has_errors).call(s) }
      is_invalid { |s| negate(:is_valid).call(s) }
    end

    error_free_state = test_state(errors: [], valid: true)
    error_state = test_state(errors: ['Error 1'], valid: true)
    invalid_state = test_state(errors: [], valid: false)

    # Error-free state should pass no_errors
    assert predicates.call(:no_errors, error_free_state)
    assert predicates.call(:is_valid, error_free_state)
    refute predicates.call(:is_invalid, error_free_state)

    # Error state should fail no_errors
    refute predicates.call(:no_errors, error_state)
    assert predicates.call(:is_valid, error_state)
    refute predicates.call(:is_invalid, error_state)

    # Invalid state should pass is_invalid
    assert predicates.call(:no_errors, invalid_state)
    refute predicates.call(:is_valid, invalid_state)
    assert predicates.call(:is_invalid, invalid_state)
  end

  # Test WHEN_PRESENT combinator
  def test_when_present_combinator
    predicates = Predicate.define(@entity) do
      title_length_check do |s|
        when_present(:title) do |state|
          min_length?(state[:title], 5)
        end.call(s)
      end
      description_length_check do |s|
        when_present(:description, default_value: false) do |state|
          min_length?(state[:description], 10)
        end.call(s)
      end
    end

    # States with present fields
    valid_title_state = test_state(title: 'Valid Title', description: nil)
    short_title_state = test_state(title: 'Hi', description: nil)
    valid_description_state = test_state(title: nil,
                                         description: 'Valid description with enough content')
    short_description_state = test_state(title: nil, description: 'Short')

    # States with missing fields
    no_title_state = test_state(title: nil, description: nil)
    no_description_state = test_state(title: nil, description: nil)

    # When field is present, predicate should be evaluated
    assert predicates.call(:title_length_check, valid_title_state)
    refute predicates.call(:title_length_check, short_title_state)

    assert predicates.call(:description_length_check, valid_description_state)
    refute predicates.call(:description_length_check, short_description_state)

    # When field is not present, default value should be returned
    assert predicates.call(:title_length_check, no_title_state) # default_value: true
    refute predicates.call(:description_length_check, no_description_state) # default_value: false
  end

  # Test WHEN_BLANK combinator
  def test_when_blank_combinator
    predicates = Predicate.define(@entity) do
      default_title_check do |s|
        when_blank(:title) do |state|
          is_present?(state[:default_title])
        end.call(s)
      end
      fallback_description_check do |s|
        when_blank(:description, default_value: true) do |state|
          is_present?(state[:fallback_description])
        end.call(s)
      end
    end

    # States with blank fields
    blank_title_with_default = test_state(title: nil, default_title: 'Default Title')
    blank_title_no_default = test_state(title: nil, default_title: nil)
    blank_description_with_fallback = test_state(description: nil, fallback_description: 'Fallback')
    blank_description_no_fallback = test_state(description: nil, fallback_description: nil)

    # States with present fields
    present_title_state = test_state(title: 'Present Title', default_title: 'Default Title')
    present_description_state = test_state(description: 'Present Description',
                                           fallback_description: 'Fallback')

    # When field is blank, predicate should be evaluated
    assert predicates.call(:default_title_check, blank_title_with_default)
    refute predicates.call(:default_title_check, blank_title_no_default)

    assert predicates.call(:fallback_description_check, blank_description_with_fallback)
    refute predicates.call(:fallback_description_check, blank_description_no_fallback)

    # When field is present, default value should be returned
    refute predicates.call(:default_title_check, present_title_state) # default_value: false
    assert predicates.call(:fallback_description_check, present_description_state) # default_value: true
  end

  # Test complex combinator combinations
  def test_complex_combinator_combinations
    predicates = Predicate.define(@entity) do
      has_title { |s| is_present?(s[:title]) }
      has_description { |s| is_present?(s[:description]) }
      has_media { |s| is_present?(s[:media_attachment_ids]) }
      has_tags { |s| is_present?(s[:tags]) && has_elements?(s[:tags]) }
      is_published { |s| s[:published] == true }
      is_valid { |s| s[:valid] == true }

      # Complex: Has content AND (has media OR has tags) AND is valid AND not published
      ready_for_review do |s|
        all_of(
          :is_valid,
          any_of(:has_title, :has_description),
          any_of(:has_media, :has_tags),
          negate(:is_published)
        ).call(s)
      end

      # Complex: When title is present, check length, otherwise check if has description
      content_requirement do |s|
        any_of(
          when_present(:title) { |state| min_length?(state[:title], 5) },
          when_blank(:title) { |state| is_present?(state[:description]) }
        ).call(s)
      end
    end

    # State that meets all requirements
    ready_state = test_state(
      title: 'Valid Title',
      description: 'Valid Description',
      media_attachment_ids: [1, 2],
      tags: %w[tag1 tag2],
      published: false,
      valid: true
    )

    # State that's published (should fail)
    published_state = ready_state.merge(published: true)

    # State that's invalid (should fail)
    invalid_state = ready_state.merge(valid: false)

    # State with no media or tags (should fail)
    no_media_tags_state = ready_state.merge(media_attachment_ids: [], tags: [])

    # State with short title but has description
    short_title_with_desc = test_state(
      title: 'Hi',
      description: 'Valid Description',
      media_attachment_ids: [],
      tags: [],
      published: false,
      valid: true
    )

    # State with no title but has description
    no_title_with_desc = test_state(
      title: nil,
      description: 'Valid Description',
      media_attachment_ids: [],
      tags: [],
      published: false,
      valid: true
    )

    # Test ready_for_review
    assert predicates.call(:ready_for_review, ready_state)
    refute predicates.call(:ready_for_review, published_state)
    refute predicates.call(:ready_for_review, invalid_state)
    refute predicates.call(:ready_for_review, no_media_tags_state)

    # Test content_requirement
    assert predicates.call(:content_requirement, ready_state)
    refute predicates.call(:content_requirement, short_title_with_desc)
    assert predicates.call(:content_requirement, no_title_with_desc)
  end

  # Test error handling in combinators
  def test_error_handling_in_combinators
    predicates = Predicate.define(@entity) do
      error_predicate { |_s| raise StandardError, 'Test error' }
      safe_predicate { |s| is_present?(s[:value]) }

      all_with_error { |s| all_of(:safe_predicate, :error_predicate).call(s) }
      any_with_error { |s| any_of(:error_predicate, :safe_predicate).call(s) }
      not_with_error { |s| negate(:error_predicate).call(s) }
    end

    state = test_state(value: 'test')

    # all_of should return false if any predicate errors
    refute predicates.call(:all_with_error, state)

    # any_of should return true if any safe predicate succeeds
    assert predicates.call(:any_with_error, state)

    # not should return true if predicate errors (treated as false)
    assert predicates.call(:not_with_error, state)
  end

  # Test performance with combinators and caching
  def test_performance_with_combinators_and_caching
    call_count = 0

    predicates = Predicate.define(@entity) do
      expensive_predicate do |s|
        call_count += 1
        is_present?(s[:value])
      end

      cheap_predicate { |s| is_present?(s[:other_value]) }

      combined_check { |s| all_of(:expensive_predicate, :cheap_predicate).call(s) }
    end

    state = test_state(value: 'test', other_value: 'other')

    # First call should execute expensive predicate
    assert predicates.call(:combined_check, state)
    assert_equal 1, call_count

    # Second call should use cache for expensive predicate
    assert predicates.call(:combined_check, state)
    assert_equal 1, call_count

    # Call individual expensive predicate should also use cache
    assert predicates.call(:expensive_predicate, state)
    assert_equal 1, call_count
  end

  # Test edge cases and argument validation
  def test_edge_cases_and_validation
    core = test_predicate_core(@entity)

    # Test empty predicate list
    assert_raises(ArgumentError) { Predicate::Combinators::AllOf.new(core) }
    assert_raises(ArgumentError) { Predicate::Combinators::AnyOf.new(core) }
    assert_raises(ArgumentError) { Predicate::Combinators::NoneOf.new(core) }

    # Test when_present without block
    assert_raises(ArgumentError) { Predicate::Combinators::WhenPresent.new(core, :field) }

    # Test when_blank without block
    assert_raises(ArgumentError) { Predicate::Combinators::WhenBlank.new(core, :field) }

    # Test invalid predicate types
    assert_raises(ArgumentError) { Predicate::Combinators::AllOf.new(core, 123) }
    assert_raises(ArgumentError) { Predicate::Combinators::AnyOf.new(core, []) }
  end
end
