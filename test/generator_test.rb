# frozen_string_literal: true

require_relative 'test_helper'

# PREDICATE FILE GENERATOR TEST
# Tests for PredicateFileGenerator without ActiveSupport dependencies
#
# Features tested:
# - basic_underscore conversion without ActiveSupport
# - Generate predicates for plain Ruby classes
# - No LoadError when ActiveSupport is unavailable

class GeneratorTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test basic_underscore conversion
  def test_basic_underscore_simple_class_name
    result = Predicate::Util.underscore('User')
    assert_equal 'user', result
  end

  def test_basic_underscore_camel_case
    result = Predicate::Util.underscore('UserAccount')
    assert_equal 'user_account', result
  end

  def test_basic_underscore_multiple_words
    result = Predicate::Util.underscore('BlogPostComment')
    assert_equal 'blog_post_comment', result
  end

  def test_basic_underscore_acronym
    result = Predicate::Util.underscore('APIKey')
    assert_equal 'api_key', result
  end

  def test_basic_underscore_leading_acronym
    result = Predicate::Util.underscore('HTTPSConnection')
    assert_equal 'https_connection', result
  end

  def test_basic_underscore_all_caps
    result = Predicate::Util.underscore('API')
    assert_equal 'api', result
  end

  # Test generator works without ActiveSupport
  def test_generate_for_plain_ruby_class
    # Create a plain Ruby class (not ActiveRecord)
    test_class = Class.new do
      def self.name
        'TestModel'
      end
    end

    # Should not raise LoadError even without ActiveSupport::Inflector
    content = Predicate::ModelIntegration::PredicateFileGenerator.generate_for_model(test_class)

    # Should generate basic predicate structure
    assert_match(/Predicate\.define\(:test_model\)/, content)
    assert_match(/frozen_string_literal: true/, content)
    assert_match(/Auto-generated predicate file for TestModel/, content)
  end

  # Test generator with complex class name
  def test_generate_for_complex_class_name
    test_class = Class.new do
      def self.name
        'UserAccountSetting'
      end
    end

    content = Predicate::ModelIntegration::PredicateFileGenerator.generate_for_model(test_class)

    # Should convert to snake_case correctly
    assert_match(/Predicate\.define\(:user_account_setting\)/, content)
  end

  # Test generator doesn't crash without ActiveRecord methods
  def test_generate_for_class_without_activerecord
    test_class = Class.new do
      def self.name
        'PlainRubyClass'
      end
    end

    # Should not crash when class doesn't respond to :attribute_names or :reflect_on_all_associations
    assert_nothing_raised do
      Predicate::ModelIntegration::PredicateFileGenerator.generate_for_model(test_class)
    end
  end

  # Test that basic_underscore handles edge cases
  def test_basic_underscore_empty_string
    result = Predicate::Util.underscore('')
    assert_equal '', result
  end

  def test_basic_underscore_single_letter
    result = Predicate::Util.underscore('A')
    assert_equal 'a', result
  end

  def test_basic_underscore_lowercase_input
    result = Predicate::Util.underscore('user')
    assert_equal 'user', result
  end

  def test_basic_underscore_already_underscored
    result = Predicate::Util.underscore('user_account')
    assert_equal 'user_account', result
  end

  # Test that generator output is valid Ruby
  def test_generated_content_is_valid_ruby
    test_class = Class.new do
      def self.name
        'TestModel'
      end
    end

    content = Predicate::ModelIntegration::PredicateFileGenerator.generate_for_model(test_class)

    # Should be syntactically valid Ruby
    assert_nothing_raised do
      eval(content) # rubocop:disable Security/Eval
    end
  end
end
