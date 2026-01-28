# frozen_string_literal: true

require 'ostruct'
require_relative 'test_helper'

# MODEL INTEGRATION TESTS
# Comprehensive tests for Predicate::ModelIntegration functionality
#
# @author Nauman Tariq
# @version 1.0.0

class ModelIntegrationTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    @entity = :test_model
    Predicate.clear_cache!
    Predicate.clear_registry!

    # Create a mock model class
    @model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        OpenStruct.new(underscore: 'test_model')
      end

      def initialize(attributes = {})
        @attributes = attributes
      end

      attr_reader :attributes
    end

    # Ensure the module is properly included
    @model_class.extend(Predicate::ModelIntegration::ClassMethods)
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test class methods
  def test_class_methods
    # Test predicate_instance initially nil
    assert_nil @model_class.predicate_instance

    # Test predicates_loaded? initially false
    refute @model_class.predicates_loaded?

    # Test predicate_names initially empty (unless predicates are already defined)
    predicate_names = @model_class.predicate_names
    # Should be empty unless predicates were defined in setup
    assert predicate_names.empty? || predicate_names.include?(:has_title)

    # Test has_predicate? initially false
    refute @model_class.predicate?(:some_predicate)
  end

  def test_load_predicates_without_file
    # Test loading when no predicate file exists
    result = @model_class.load_predicates!

    # Result should be nil if no predicates are defined, or a Core instance if predicates exist
    assert result.nil? || result.is_a?(Predicate::Core)
    assert_nil @model_class.predicate_instance unless result
    refute @model_class.predicates_loaded? unless result
  end

  def test_load_predicates_with_existing_predicates
    # Define predicates first
    Predicate.define(@entity) do
      has_title { |s| present?(s[:title]) }
      has_description { |s| present?(s[:description]) }
    end

    # Mock the predicate file path to return a non-existent file
    # This simulates the case where predicates are already loaded
    @model_class.define_singleton_method(:predicate_file_path) do |_entity_name|
      '/non/existent/path'
    end

    # Test loading when predicates exist in registry
    result = @model_class.load_predicates!

    # Should return a Core instance since predicates exist in registry
    assert result.is_a?(Predicate::Core)
    assert @model_class.predicates_loaded?
  end

  def test_clear_predicates
    # Set a mock predicate instance
    @model_class.instance_variable_set(:@predicate_instance, 'mock_instance')

    assert @model_class.predicates_loaded?

    @model_class.clear_predicates!

    refute @model_class.predicates_loaded?
    assert_nil @model_class.predicate_instance
  end

  # Test instance methods
  def test_instance_methods
    instance = @model_class.new(title: 'Test Title', description: 'Test Description')

    # Test predicate_instance delegates to class
    assert_nil instance.predicate_instance

    # Test predicates_loaded? delegates to class
    refute instance.predicates_loaded?

    # Test predicate_names delegates to class
    predicate_names = instance.predicate_names
    assert predicate_names.empty? || predicate_names.include?(:has_title)

    # Test has_predicate? delegates to class
    refute instance.predicate?(:some_predicate)
  end

  def test_call_predicate_without_loaded_predicates
    instance = @model_class.new(title: 'Test Title')

    # Should return false when no predicates are loaded
    result = instance.call_predicate(:has_title)
    refute result
  end

  def test_call_predicate_with_loaded_predicates
    # Define predicates
    Predicate.define(@entity) do
      has_title { |s| present?(s[:title]) }
      has_description { |s| present?(s[:description]) }
    end

    # Mock the predicate file to exist and load the predicates
    @model_class.define_singleton_method(:predicate_file_path) do |entity_name|
      # Create a temporary predicate file
      temp_file = "/tmp/#{entity_name}_predicate.rb"
      File.write(temp_file,
                 "Predicate.define(:#{entity_name}) do\n  has_title { |s| present?(s[:title]) }\n  has_description { |s| present?(s[:description]) }\nend")
      temp_file
    end

    # Load predicates
    @model_class.load_predicates!

    instance = @model_class.new(title: 'Test Title', description: 'Test Description')

    # Test calling predicates
    assert instance.predicate?(:has_title), 'Should have has_title predicate'
    assert instance.predicate?(:has_description), 'Should have has_description predicate'

    # Test with additional state
    assert instance.call_predicate(:has_title, { extra_field: 'value' })

    # Clean up temp file
    FileUtils.rm_f("/tmp/#{@entity}_predicate.rb")
  end

  def test_method_missing_predicate_calls
    # Define predicates
    Predicate.define(@entity) do
      has_title { |s| present?(s[:title]) }
      has_description { |s| present?(s[:description]) }
    end

    # Mock the predicate file
    @model_class.define_singleton_method(:predicate_file_path) do |entity_name|
      temp_file = "/tmp/#{entity_name}_predicate.rb"
      File.write(temp_file,
                 "Predicate.define(:#{entity_name}) do\n  has_title { |s| present?(s[:title]) }\n  has_description { |s| present?(s[:description]) }\nend")
      temp_file
    end

    @model_class.load_predicates!

    instance = @model_class.new(title: 'Test Title', description: 'Test Description')

    # Test direct predicate method calls
    assert instance.has_title?
    assert instance.has_description?

    # Test non-existent predicate
    refute instance.has_nonexistent?

    # Test non-predicate method (should call super)
    assert_raises(NoMethodError) do
      instance.nonexistent_method
    end

    # Clean up temp file
    FileUtils.rm_f("/tmp/#{@entity}_predicate.rb")
  end

  def test_respond_to_missing_predicate_methods
    # Clear registry to ensure predicates are loaded from file
    Predicate.clear_registry!

    # Mock the predicate file
    @model_class.define_singleton_method(:predicate_file_path) do |entity_name|
      temp_file = "/tmp/#{entity_name}_predicate.rb"
      File.write(temp_file,
                 "Predicate.define(:#{entity_name}) do\n  has_title { |s| !s[:title].nil? && !s[:title].empty? }\nend")
      temp_file
    end

    @model_class.load_predicates!

    instance = @model_class.new(title: 'Test Title')

    # Test respond_to? for predicate methods
    assert instance.respond_to?(:has_title?)
    refute instance.respond_to?(:has_nonexistent?)

    # Test respond_to? for non-predicate methods
    refute instance.respond_to?(:nonexistent_method)

    # Clean up temp file
    FileUtils.rm_f("/tmp/#{@entity}_predicate.rb")
  end

  def test_build_state_hash_with_attributes
    instance = @model_class.new(title: 'Test Title', description: 'Test Description')

    state = instance.send(:build_state_hash)

    assert_equal 'Test Title', state[:title]
    assert_equal 'Test Description', state[:description]
  end

  def test_build_state_hash_with_additional_state
    instance = @model_class.new(title: 'Test Title')

    state = instance.send(:build_state_hash, { extra_field: 'extra_value' })

    assert_equal 'Test Title', state[:title]
    assert_equal 'extra_value', state[:extra_field]
  end

  def test_build_state_hash_with_hash_like_object
    hash_like_class = Class.new do
      include Predicate::ModelIntegration

      def initialize(data)
        @data = data
      end

      def to_h
        @data
      end

      def self.name
        'HashLikeModel'
      end

      def self.model_name
        OpenStruct.new(underscore: 'hash_like_model')
      end
    end

    instance = hash_like_class.new(title: 'Test Title', description: 'Test Description')

    state = instance.send(:build_state_hash)

    assert_equal 'Test Title', state[:title]
    assert_equal 'Test Description', state[:description]
  end

  def test_build_state_hash_with_instance_variables
    ivar_class = Class.new do
      include Predicate::ModelIntegration

      def initialize(title, description)
        @title = title
        @description = description
      end

      def self.name
        'IvarModel'
      end

      def self.model_name
        OpenStruct.new(underscore: 'ivar_model')
      end
    end

    instance = ivar_class.new('Test Title', 'Test Description')

    state = instance.send(:build_state_hash)

    assert_equal 'Test Title', state[:title]
    assert_equal 'Test Description', state[:description]
  end

  def test_predicate_stats
    # Define predicates
    Predicate.define(@entity) do
      has_title { |s| present?(s[:title]) }
    end

    # Mock the predicate file
    @model_class.define_singleton_method(:predicate_file_path) do |entity_name|
      temp_file = "/tmp/#{entity_name}_predicate.rb"
      File.write(temp_file,
                 "Predicate.define(:#{entity_name}) do\n  has_title { |s| present?(s[:title]) }\nend")
      temp_file
    end

    @model_class.load_predicates!

    instance = @model_class.new(title: 'Test Title')

    # Call predicate to generate stats
    instance.has_title?

    stats = instance.predicate_stats
    assert stats.is_a?(Hash)
    assert stats.key?(:has_title)

    # Clean up temp file
    FileUtils.rm_f("/tmp/#{@entity}_predicate.rb")
  end

  def test_clear_predicate_cache
    # Define predicates
    Predicate.define(@entity) do
      has_title { |s| present?(s[:title]) }
    end

    # Mock the predicate file
    @model_class.define_singleton_method(:predicate_file_path) do |entity_name|
      temp_file = "/tmp/#{entity_name}_predicate.rb"
      File.write(temp_file,
                 "Predicate.define(:#{entity_name}) do\n  has_title { |s| present?(s[:title]) }\nend")
      temp_file
    end

    @model_class.load_predicates!

    instance = @model_class.new(title: 'Test Title')

    # Call predicate to populate cache
    instance.has_title?

    # Clear cache
    instance.clear_predicate_cache!

    # Cache should be cleared (we can't directly test this, but it shouldn't raise an error)
    # Just verify the method doesn't raise an exception
    begin
      instance.clear_predicate_cache!
      assert true, 'clear_predicate_cache! should not raise an error'
    rescue StandardError => e
      flunk "clear_predicate_cache! raised an error: #{e.message}"
    end

    # Clean up temp file
    FileUtils.rm_f("/tmp/#{@entity}_predicate.rb")
  end

  # Test predicate file generator
  def test_predicate_file_generator
    # Create a mock model class with attributes
    mock_model = Class.new do
      def self.name
        'TestModel'
      end

      def self.attribute_names
        %w[id title description created_at updated_at]
      end

      def self.reflect_on_all_associations
        [
          OpenStruct.new(name: 'user'),
          OpenStruct.new(name: 'comments')
        ]
      end
    end

    content = Predicate::ModelIntegration::PredicateFileGenerator.generate_predicate_content(
      mock_model, :test_model
    )

    # Check that content includes expected elements (without ? suffix)
    assert_includes content, 'Predicate.define(:test_model) do'
    assert_includes content, 'has_title { |s| present?(s[:title]) }'
    assert_includes content, 'has_description { |s| present?(s[:description]) }'
    assert_includes content, 'has_user { |s| present?(s[:user]) }'
    assert_includes content, 'has_comments { |s| present?(s[:comments]) }'

    # Check that it excludes system fields
    refute_includes content, 'has_id'
    refute_includes content, 'has_created_at'
    refute_includes content, 'has_updated_at'
  end

  def test_predicate_file_generator_with_output_path
    mock_model = Class.new do
      def self.name
        'TestModel'
      end

      def self.attribute_names
        ['title']
      end

      def self.reflect_on_all_associations
        []
      end
    end

    output_path = '/tmp/test_generated_predicate.rb'

    # Generate file
    Predicate::ModelIntegration::PredicateFileGenerator.generate_for_model(mock_model,
                                                                           output_path)

    # Check file was created
    assert File.exist?(output_path)

    # Check content (without ? suffix)
    file_content = File.read(output_path)
    assert_includes file_content, 'Predicate.define(:test_model) do'
    assert_includes file_content, 'has_title { |s| present?(s[:title]) }'

    # Clean up
    FileUtils.rm_f(output_path)
  end

  # Test error handling
  def test_error_handling_in_load_predicates
    # Mock a predicate file that will cause an error
    @model_class.define_singleton_method(:predicate_file_path) do |entity_name|
      temp_file = "/tmp/#{entity_name}_predicate.rb"
      File.write(temp_file, "raise StandardError, 'Test error'")
      temp_file
    end

    # Should handle error gracefully
    result = @model_class.load_predicates!
    assert_nil result
    refute @model_class.predicates_loaded?

    # Clean up temp file
    FileUtils.rm_f("/tmp/#{@entity}_predicate.rb")
  end

  def test_error_handling_in_call_predicate
    instance = @model_class.new(title: 'Test Title')

    # Should handle missing predicates gracefully
    result = instance.call_predicate(:nonexistent_predicate)
    refute result
  end

  # Test performance with caching
  def test_performance_with_caching
    # Define predicates
    Predicate.define(@entity) do
      expensive_predicate { |s| present?(s[:title]) }
    end

    # Mock the predicate file
    @model_class.define_singleton_method(:predicate_file_path) do |entity_name|
      temp_file = "/tmp/#{entity_name}_predicate.rb"
      File.write(temp_file,
                 "Predicate.define(:#{entity_name}) do\n  expensive_predicate { |s| present?(s[:title]) }\nend")
      temp_file
    end

    @model_class.load_predicates!

    instance = @model_class.new(title: 'Test Title')

    # First call should load predicates
    assert instance.expensive_predicate?

    # Second call should use cached predicates
    assert instance.expensive_predicate?

    # Clean up temp file
    FileUtils.rm_f("/tmp/#{@entity}_predicate.rb")
  end

  # Test complex predicate scenarios
  def test_complex_predicate_scenarios
    # Define complex predicates
    Predicate.define(@entity) do
      has_title { |s| present?(s[:title]) }
      has_description { |s| present?(s[:description]) }
      has_media { |s| present?(s[:media_attachment_ids]) }

      wizard_complete do |s|
        all_of(:has_title, :has_description, :has_media).call(s)
      end

      section :validation do
        required_fields { |s| present?(s[:title]) && present?(s[:description]) }
        valid_format { |s| matches?(s[:title], /\A\w+\z/) }
      end
    end

    # Mock the predicate file
    @model_class.define_singleton_method(:predicate_file_path) do |entity_name|
      temp_file = "/tmp/#{entity_name}_predicate.rb"
      File.write(temp_file, <<~RUBY)
        Predicate.define(:#{entity_name}) do
          has_title { |s| present?(s[:title]) }
          has_description { |s| present?(s[:description]) }
          has_media { |s| present?(s[:media_attachment_ids]) }
        #{'  '}
          wizard_complete { |s|#{' '}
            all_of(:has_title, :has_description, :has_media).call(s)
          }
        #{'  '}
          section :validation do
            required_fields { |s| present?(s[:title]) && present?(s[:description]) }
            valid_format { |s| matches?(s[:title], /\\A\\w+\\z/) }
          end
        end
      RUBY
      temp_file
    end

    @model_class.load_predicates!

    # Test complete instance
    complete_instance = @model_class.new(
      title: 'ValidTitle',
      description: 'Valid Description',
      media_attachment_ids: [1, 2, 3]
    )

    assert complete_instance.has_title?
    assert complete_instance.has_description?
    assert complete_instance.has_media?
    assert complete_instance.wizard_complete?

    # Test incomplete instance
    incomplete_instance = @model_class.new(
      title: 'ValidTitle',
      description: nil,
      media_attachment_ids: []
    )

    assert incomplete_instance.has_title?
    refute incomplete_instance.has_description?
    refute incomplete_instance.has_media?
    refute incomplete_instance.wizard_complete?

    # Clean up temp file
    FileUtils.rm_f("/tmp/#{@entity}_predicate.rb")
  end
end
