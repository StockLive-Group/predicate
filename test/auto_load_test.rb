# frozen_string_literal: true

require 'ostruct'
require_relative 'test_helper'

# AUTO LOAD TEST
# Tests for the auto-load feature where `include Predicate::ModelIntegration`
# automatically calls `load_predicates!` so models don't need to call it explicitly.
#
# Important: self.name and self.model_name must be defined BEFORE the include
# statement because the `included` callback immediately calls `load_predicates!`
# which requires `model_name` to resolve the entity name.

class AutoLoadTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  # ============================================================================
  # Auto-load on include
  # ============================================================================

  def test_including_model_integration_auto_loads_predicates_from_registry
    # Define predicates in registry BEFORE including ModelIntegration
    Predicate.define(:auto_load_model) do
      has_title { |s| is_present?(s[:title]) }
      has_description { |s| is_present?(s[:description]) }
    end

    # Create model class that includes ModelIntegration
    # The include triggers self.included -> load_predicates!
    # Note: self.name and self.model_name must be defined before include
    model_class = Class.new do
      def self.name
        'AutoLoadModel'
      end

      def self.model_name
        :auto_load_model
      end

      include Predicate::ModelIntegration

      attr_accessor :title, :description

      def initialize(attrs = {})
        @title = attrs[:title]
        @description = attrs[:description]
      end
    end

    # Predicates should be loaded automatically
    assert model_class.predicates_loaded?,
           'Predicates should be loaded automatically after include'
    assert_instance_of Predicate::Core, model_class.predicate_instance,
                       'predicate_instance should be a Predicate::Core'
  end

  # ============================================================================
  # predicates_loaded? returns true after include
  # ============================================================================

  def test_predicates_loaded_returns_true_after_include
    Predicate.define(:loaded_check_model) do
      has_name { |s| is_present?(s[:name]) }
    end

    model_class = Class.new do
      def self.name
        'LoadedCheckModel'
      end

      def self.model_name
        :loaded_check_model
      end

      include Predicate::ModelIntegration
    end

    assert model_class.predicates_loaded?,
           'predicates_loaded? should return true after including ModelIntegration with registered predicates'
  end

  # ============================================================================
  # Predicate methods callable without explicit load_predicates!
  # ============================================================================

  def test_predicate_methods_callable_without_explicit_load
    Predicate.define(:callable_model) do
      has_title { |s| is_present?(s[:title]) }
      has_description { |s| is_present?(s[:description]) }
    end

    model_class = Class.new do
      def self.name
        'CallableModel'
      end

      def self.model_name
        :callable_model
      end

      include Predicate::ModelIntegration

      attr_accessor :title, :description

      def initialize(attrs = {})
        @title = attrs[:title]
        @description = attrs[:description]
      end
    end

    # Create instance and call predicate methods directly (no explicit load_predicates!)
    instance = model_class.new(title: 'Test Title', description: nil)

    assert instance.has_title?,
           'has_title? should return true without explicit load_predicates!'
    refute instance.has_description?,
           'has_description? should return false for nil description without explicit load_predicates!'

    # Test with both present
    instance2 = model_class.new(title: 'Title', description: 'Description')
    assert instance2.has_title?, 'has_title? should return true'
    assert instance2.has_description?, 'has_description? should return true'
  end

  def test_call_predicate_works_without_explicit_load
    Predicate.define(:call_pred_model) do
      has_name { |s| is_present?(s[:name]) }
    end

    model_class = Class.new do
      def self.name
        'CallPredModel'
      end

      def self.model_name
        :call_pred_model
      end

      include Predicate::ModelIntegration

      attr_accessor :name

      def initialize(attrs = {})
        @name = attrs[:name]
      end
    end

    instance = model_class.new(name: 'John')

    # call_predicate should work without needing explicit load_predicates!
    assert instance.call_predicate(:has_name),
           'call_predicate should work without explicit load_predicates!'
  end

  def test_predicate_names_available_without_explicit_load
    Predicate.define(:names_model) do
      has_title { |s| is_present?(s[:title]) }
      has_body { |s| is_present?(s[:body]) }
    end

    model_class = Class.new do
      def self.name
        'NamesModel'
      end

      def self.model_name
        :names_model
      end

      include Predicate::ModelIntegration
    end

    # predicate_names should be available without explicit load
    names = model_class.predicate_names
    assert_includes names, :has_title, 'predicate_names should include :has_title'
    assert_includes names, :has_body, 'predicate_names should include :has_body'
  end

  def test_predicate_existence_check_without_explicit_load
    Predicate.define(:exist_check_model) do
      has_value { |s| is_present?(s[:value]) }
    end

    model_class = Class.new do
      def self.name
        'ExistCheckModel'
      end

      def self.model_name
        :exist_check_model
      end

      include Predicate::ModelIntegration
    end

    assert model_class.predicate?(:has_value),
           'predicate?(:has_value) should return true without explicit load'
    refute model_class.predicate?(:nonexistent),
           'predicate?(:nonexistent) should return false'
  end

  # ============================================================================
  # force_reload still works
  # ============================================================================

  def test_load_predicates_with_force_reload_still_works
    Predicate.define(:reload_model) do
      has_title { |s| is_present?(s[:title]) }
    end

    model_class = Class.new do
      def self.name
        'ReloadModel'
      end

      def self.model_name
        :reload_model
      end

      include Predicate::ModelIntegration

      attr_accessor :title, :description

      def initialize(attrs = {})
        @title = attrs[:title]
        @description = attrs[:description]
      end
    end

    # Predicates should already be loaded via auto-load
    assert model_class.predicates_loaded?

    # Redefine predicates with additional predicate
    Predicate.define(:reload_model) do
      has_title { |s| is_present?(s[:title]) }
      has_description { |s| is_present?(s[:description]) }
    end

    # Force reload to pick up new definitions
    result = model_class.load_predicates!(force_reload: true)

    assert result.is_a?(Predicate::Core),
           'force_reload should return a Core instance'
    assert model_class.predicates_loaded?,
           'predicates_loaded? should still be true after force reload'

    # Verify new predicate is available
    instance = model_class.new(description: 'Test')
    assert instance.has_description?,
           'New predicate should be available after force reload'
  end

  # ============================================================================
  # Graceful handling when no predicates are defined
  # ============================================================================

  def test_including_model_integration_without_predicates_defined_does_not_error
    # No predicates are defined for this model in the registry
    assert_nothing_raised do
      Class.new do
        def self.name
          'NoPredicateModel'
        end

        def self.model_name
          :no_predicate_model
        end

        include Predicate::ModelIntegration
      end
    end
  end

  def test_predicates_loaded_false_when_no_predicates_defined
    model_class = Class.new do
      def self.name
        'EmptyModel'
      end

      def self.model_name
        :empty_model
      end

      include Predicate::ModelIntegration
    end

    refute model_class.predicates_loaded?,
           'predicates_loaded? should return false when no predicates are defined'
    assert_nil model_class.predicate_instance,
               'predicate_instance should be nil when no predicates are defined'
  end

  def test_predicate_methods_return_false_when_no_predicates_defined
    model_class = Class.new do
      def self.name
        'FallbackModel'
      end

      def self.model_name
        :fallback_model
      end

      include Predicate::ModelIntegration

      def initialize
        @value = 'test'
      end
    end

    instance = model_class.new

    # Calling a predicate-style method should return false gracefully
    refute instance.has_something?,
           'Predicate method should return false when no predicates are defined'
  end

  def test_call_predicate_returns_false_when_no_predicates_defined
    model_class = Class.new do
      def self.name
        'NoPredModel'
      end

      def self.model_name
        :no_pred_model
      end

      include Predicate::ModelIntegration

      def initialize
        @data = {}
      end
    end

    instance = model_class.new
    result = instance.call_predicate(:anything)
    refute result, 'call_predicate should return false when no predicates are loaded'
  end

  # ============================================================================
  # Model still works if predicate file doesn't exist
  # ============================================================================

  def test_model_works_when_predicate_file_does_not_exist
    # This model has no predicates in the registry and no predicate file on disk
    model_class = Class.new do
      def self.name
        'FilelessModel'
      end

      def self.model_name
        :fileless_model
      end

      include Predicate::ModelIntegration

      attr_accessor :name

      def initialize(name = nil)
        @name = name
      end
    end

    # Model should be usable without errors
    instance = model_class.new('Test')
    assert_equal 'Test', instance.name,
                 'Model attributes should work even without predicate file'

    refute model_class.predicates_loaded?,
           'predicates_loaded? should be false when no file exists'
    assert_equal [], model_class.predicate_names,
                 'predicate_names should be empty when no file exists'
  end

  def test_model_with_explicit_nonexistent_predicate_file_path
    model_class = Class.new do
      def self.name
        'MissingFileModel'
      end

      def self.model_name
        :missing_file_model
      end

      include Predicate::ModelIntegration
    end

    # Override predicate_file_path to point to a definitely nonexistent file
    model_class.define_singleton_method(:predicate_file_path) do |_entity_name|
      '/definitely/nonexistent/path/missing_file_model_predicate.rb'
    end

    # Should not raise and should handle gracefully
    assert_nothing_raised do
      model_class.load_predicates!
    end

    refute model_class.predicates_loaded?,
           'predicates_loaded? should be false for nonexistent file'
  end

  # ============================================================================
  # Model with different model_name formats
  # ============================================================================

  def test_auto_load_with_openstruct_model_name
    Predicate.define(:ostruct_model) do
      has_value { |s| is_present?(s[:value]) }
    end

    model_class = Class.new do
      def self.name
        'OstructModel'
      end

      def self.model_name
        OpenStruct.new(underscore: 'ostruct_model')
      end

      include Predicate::ModelIntegration

      def initialize(attrs = {})
        @value = attrs[:value]
      end

      def attributes
        { value: @value }
      end
    end

    assert model_class.predicates_loaded?,
           'Auto-load should work with OpenStruct model_name'

    instance = model_class.new(value: 'test')
    assert instance.has_value?,
           'Predicate should work with OpenStruct-based model_name'
  end

  # ============================================================================
  # respond_to_missing? works after auto-load
  # ============================================================================

  def test_respond_to_missing_works_after_auto_load
    Predicate.define(:respond_model) do
      has_name { |s| is_present?(s[:name]) }
    end

    model_class = Class.new do
      def self.name
        'RespondModel'
      end

      def self.model_name
        :respond_model
      end

      include Predicate::ModelIntegration

      def initialize(attrs = {})
        @name = attrs[:name]
      end
    end

    instance = model_class.new(name: 'Test')

    assert instance.respond_to?(:has_name?),
           'Instance should respond_to? :has_name? after auto-load'
    refute instance.respond_to?(:has_nonexistent?),
           'Instance should not respond_to? :has_nonexistent?'
    refute instance.respond_to?(:totally_unrelated_method),
           'Instance should not respond_to? non-predicate methods'
  end
end
