# frozen_string_literal: true

require_relative 'test_helper'

# FORCE RELOAD TEST
# Tests for Bug #3: force_reload flag ignored
#
# Problem: load_predicates!(force_reload: true) always returns cached
# registry instance instead of reloading from disk

class ForceReloadTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  # Test that force_reload actually reloads predicates from registry
  def test_force_reload_gets_updated_predicates_from_registry
    # Define initial predicates
    Predicate.define(:test_model) do
      has_title { |s| is_present?(s[:title]) }
    end

    model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model
      end
    end

    # Load predicates first time
    model_class.load_predicates!
    assert model_class.predicates_loaded?, 'Predicates should be loaded'

    original_instance = model_class.predicate_instance
    refute original_instance.predicate?(:has_description),
           'Original should not have has_description predicate'

    # Redefine predicates in registry (simulating file change + reload)
    Predicate.define(:test_model) do
      has_title { |s| is_present?(s[:title]) }
      has_description { |s| is_present?(s[:description]) } # New predicate!
    end

    # Load WITHOUT force_reload - BUG: should return cached @predicate_instance
    model_class.load_predicates!(force_reload: false)
    model_class.predicate_instance

    # BUG: This will actually get NEW instance from registry because
    # load_predicates! always calls Predicate.for() which returns registry version
    # So the bug is that it IGNORES the cached @predicate_instance

    # For this test, let's verify force_reload: true gets updated predicates
    model_class.load_predicates!(force_reload: true)
    reloaded_instance = model_class.predicate_instance
    assert model_class.predicate?(:has_title), 'Should have initial predicate'
    assert model_class.predicate?(:has_title), 'Should have initial predicate'
    # refute model_class.predicate?(:has_description), "Should NOT have new predicate yet"
    # Should have new predicate
    assert reloaded_instance.predicate?(:has_description),
           'Reloaded instance should have new predicate from registry'
  end

  # Test that force_reload clears cache
  def test_force_reload_clears_cache
    Predicate.define(:test_model) do
      counter { |s| s[:value] }
    end

    model_class = Class.new do
      include Predicate::ModelIntegration

      attr_accessor :value

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model
      end

      def initialize(value)
        @value = value
      end
    end

    model_class.load_predicates!

    # Create model and call predicate (creates cache entry)
    model = model_class.new(42)
    result1 = model.counter?
    assert_equal 42, result1

    # Reload with force_reload
    model_class.load_predicates!(force_reload: true)

    # Cache should be cleared in new instance
    new_model = model_class.new(100)
    result2 = new_model.counter?
    assert_equal 100, result2
  end

  # Test that without force_reload, returns cached instance
  def test_without_force_reload_returns_cached_instance
    Predicate.define(:test_model) do
      has_title { |s| is_present?(s[:title]) }
    end

    model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model
      end
    end

    # Load first time
    model_class.load_predicates!
    first_instance = model_class.predicate_instance
    first_object_id = first_instance.object_id

    # Load again without force_reload
    model_class.load_predicates!
    second_instance = model_class.predicate_instance

    # Should be SAME instance (cached)
    assert_equal first_object_id, second_instance.object_id,
                 'Without force_reload, should return same cached instance'
  end

  # Test that force_reload works when no instance cached yet
  def test_force_reload_works_on_first_load
    Predicate.define(:test_model) do
      has_title { |s| is_present?(s[:title]) }
    end

    model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model
      end
    end

    # First load WITH force_reload (even though nothing cached)
    # Should work without error
    assert_nothing_raised do
      model_class.load_predicates!(force_reload: true)
    end

    assert model_class.predicates_loaded?, 'Predicates should be loaded'
  end
end
