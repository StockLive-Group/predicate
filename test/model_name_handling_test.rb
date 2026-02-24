# frozen_string_literal: true

require_relative 'test_helper'

# MODEL NAME HANDLING TESTS
# Test that model_name is handled flexibly for different types
#
# The library should work with:
# - Rails ActiveModel::Name objects
# - OpenStruct mocks (for testing)
# - Plain strings
# - Any object that responds to .to_s

class ModelNameHandlingTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test with OpenStruct (what the failing tests use)
  def test_model_name_with_openstruct
    model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        # This is what the current tests use
        Struct.new(:underscore).new('test_model')
      end
    end

    # Define predicates for this model
    Predicate.define(:test_model) do
      has_title { |s| is_present?(s[:title]) }
    end

    # This should work without crashing
    result = model_class.load_predicates!

    assert result.is_a?(Predicate::Core), 'Should load predicates from registry'
    assert model_class.predicates_loaded?
  end

  # Test with plain string
  def test_model_name_with_string
    model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        'TestModel' # Plain string
      end
    end

    Predicate.define(:test_model) do
      has_title { |s| is_present?(s[:title]) }
    end

    result = model_class.load_predicates!

    assert result.is_a?(Predicate::Core)
    assert model_class.predicates_loaded?
  end

  # Test with object that has param_key (like Rails)
  def test_model_name_with_param_key
    model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        # Simulate Rails ActiveModel::Name
        Struct.new(:param_key, :singular, :to_s).new(
          'test_model',
          'test_model',
          'TestModel'
        )
      end
    end

    Predicate.define(:test_model) do
      has_title { |s| is_present?(s[:title]) }
    end

    result = model_class.load_predicates!

    assert result.is_a?(Predicate::Core)
    assert model_class.predicates_loaded?
  end

  # Test with symbol
  def test_model_name_with_symbol
    model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model # Symbol
      end
    end

    Predicate.define(:test_model) do
      has_title { |s| is_present?(s[:title]) }
    end

    result = model_class.load_predicates!

    assert result.is_a?(Predicate::Core)
    assert model_class.predicates_loaded?
  end

  # Test edge case: model_name returns nil
  def test_model_name_with_nil
    model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        nil
      end
    end

    # Should handle gracefully
    result = model_class.load_predicates!

    # Should return nil since we can't determine entity name
    assert_nil result
  end

  # Test that different model_name formats produce same entity_name
  def test_consistent_entity_name_extraction
    # All these should produce :test_model
    test_cases = [
      Struct.new(:underscore).new('test_model'),
      Struct.new(:param_key, :to_s).new('test_model', 'TestModel'),
      'TestModel',
      :test_model,
      'test_model'
    ]

    test_cases.each_with_index do |model_name_value, idx|
      model_class = Class.new do
        include Predicate::ModelIntegration

        define_singleton_method(:name) { "TestModel#{idx}" }
        define_singleton_method(:model_name) { model_name_value }
      end

      Predicate.define(:test_model) do
        test_predicate { |_s| true }
      end

      result = model_class.load_predicates!

      assert result.is_a?(Predicate::Core),
             "Failed for model_name type: #{model_name_value.class} (#{model_name_value.inspect})"
    end
  end
end
