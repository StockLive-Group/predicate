# frozen_string_literal: true

require_relative 'test_helper'

# VALIDATION HELPERS BUG TEST
# Tests for Bug #1: ValidationHelpers predicates never callable
#
# Problem: validates_presence_of stores predicates with ? suffix
# but ModelIntegration strips ? before lookup = NEVER FOUND

class ValidationHelpersBugTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!
  end

  def teardown
    Predicate.clear_cache!
  end

  # Test that validates_presence_of predicates are callable via models
  def test_validates_presence_of_predicates_callable_from_model
    # Define predicates using validates_presence_of
    Predicate.define(:test_model) do
      validates_presence_of(:title, :description)
    end

    # Create mock model
    model_class = Class.new do
      include Predicate::ModelIntegration

      attr_accessor :title, :description

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model
      end

      def initialize(attrs = {})
        @title = attrs[:title]
        @description = attrs[:description]
      end
    end

    # Load predicates
    model_class.load_predicates!

    # Create instance with title
    model = model_class.new(title: 'Test Title')

    # This should work but currently returns false due to bug
    assert model.has_title?, 'has_title? should return true when title is present'
    refute model.has_description?, 'has_description? should return false when description is nil'

    # With both fields
    model2 = model_class.new(title: 'Test', description: 'Desc')
    assert model2.has_title?, 'has_title? should return true'
    assert model2.has_description?, 'has_description? should return true'
    assert model2.required_fields?, 'required_fields? should return true when all present'
  end

  # Test that validates_format_of predicates are callable
  def test_validates_format_of_predicates_callable_from_model
    Predicate.define(:test_model) do
      validates_format_of(:email, with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
    end

    model_class = Class.new do
      include Predicate::ModelIntegration

      attr_accessor :email

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model
      end

      def initialize(email)
        @email = email
      end
    end

    model_class.load_predicates!

    valid_model = model_class.new('test@example.com')
    assert valid_model.valid_email_format?, 'valid_email_format? should return true for valid email'

    invalid_model = model_class.new('invalid-email')
    refute invalid_model.valid_email_format?,
           'valid_email_format? should return false for invalid email'
  end

  # Test that validates_length_of predicates are callable
  def test_validates_length_of_predicates_callable_from_model
    Predicate.define(:test_model) do
      validates_length_of(:name, minimum: 3, maximum: 50)
    end

    model_class = Class.new do
      include Predicate::ModelIntegration

      attr_accessor :name

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model
      end

      def initialize(name)
        @name = name
      end
    end

    model_class.load_predicates!

    valid_model = model_class.new('John')
    assert valid_model.valid_name_length?, 'valid_name_length? should return true for valid length'

    too_short = model_class.new('Jo')
    refute too_short.valid_name_length?, 'valid_name_length? should return false for too short'

    too_long = model_class.new('A' * 51)
    refute too_long.valid_name_length?, 'valid_name_length? should return false for too long'
  end

  # Test that validates_numericality_of predicates are callable
  def test_validates_numericality_of_predicates_callable_from_model
    Predicate.define(:test_model) do
      validates_numericality_of(:age, greater_than: 0, less_than: 150)
    end

    model_class = Class.new do
      include Predicate::ModelIntegration

      attr_accessor :age

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model
      end

      def initialize(age)
        @age = age
      end
    end

    model_class.load_predicates!

    valid_model = model_class.new(25)
    assert valid_model.valid_age?, 'valid_age? should return true for valid number'

    invalid_model = model_class.new(0)
    refute invalid_model.valid_age?, 'valid_age? should return false for invalid number'
  end

  # Test predicate names are stored correctly
  def test_predicate_names_stored_without_question_mark
    Predicate.define(:test_model) do
      validates_presence_of(:title)
    end

    predicates = Predicate.for(:test_model)

    # After fix, predicates should be stored WITHOUT ? suffix
    assert predicates.predicate?(:has_title),
           'Predicate should be stored as :has_title (without ?)'

    refute predicates.predicate?(:has_title?),
           'Predicate should NOT be stored with ? suffix'
  end

  # Test that predicate_names returns correct names
  def test_predicate_names_returns_correct_format
    Predicate.define(:test_model) do
      validates_presence_of(:title, :description)
      validates_format_of(:email, with: /@/)
    end

    predicates = Predicate.for(:test_model)
    names = predicates.predicate_names

    # Should include names without ? suffix
    assert names.include?(:has_title), 'Should include :has_title'
    assert names.include?(:has_description), 'Should include :has_description'
    assert predicates.predicate?(:has_title), 'Should have has_title predicate'
    # assert predicates.predicate?(:required_fields), "Should have required_fields predicate"
  end
end
