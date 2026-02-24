# frozen_string_literal: true

require_relative 'test_helper'
require 'tempfile'
require 'fileutils'

# FORCE RELOAD FILE LOADING TEST
# Tests for Bug #3: force_reload should reload from file, not just registry

class ForceReloadFileTest < Minitest::Test
  include Predicate::Test::Helper

  def setup
    Predicate.clear_cache!
    Predicate.clear_registry!

    # Create temp directory for predicate files
    @temp_dir = Dir.mktmpdir
    @predicate_file = File.join(@temp_dir, 'test_model_predicate.rb')
  end

  def teardown
    Predicate.clear_cache!
    Predicate.clear_registry!
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  # Test the actual bug: force_reload doesn't reload from file
  def test_force_reload_ignores_file_changes
    # Write initial predicate file
    File.write(@predicate_file, <<~RUBY)
      Predicate.define(:test_model) do
        has_title { |s| is_present?(s[:title]) }
      end
    RUBY

    model_class = Class.new do
      include Predicate::ModelIntegration

      def self.name
        'TestModel'
      end

      def self.model_name
        :test_model
      end
    end

    # Override predicate_file_path to use our temp file
    temp_dir = @temp_dir
    model_class.define_singleton_method(:predicate_file_path) do |entity_name|
      File.join(temp_dir, "#{entity_name}_predicate.rb")
    end

    # Load predicates from file
    model_class.load_predicates!
    first_instance = model_class.predicate_instance

    assert model_class.predicate?(:has_title), 'Should have initial predicate'
    refute model_class.predicate?(:has_description), 'Should NOT have new predicate yet'

    # Now UPDATE the file (simulating developer editing file)
    File.write(@predicate_file, <<~RUBY)
      Predicate.define(:test_model) do
        has_title { |s| is_present?(s[:title]) }
        has_description { |s| is_present?(s[:description]) }  # NEW!
      end
    RUBY

    # BUG: Even with force_reload: true, it won't reload from file
    # It will return the SAME instance from registry
    model_class.load_predicates!(force_reload: true)
    reloaded_instance = model_class.predicate_instance

    # This SHOULD pass (file has new predicate) but WILL FAIL due to bug
    assert reloaded_instance.predicate?(:has_description),
           'After force_reload, should have new predicate from file'

    # Instances should be DIFFERENT (reloaded from file)
    refute_equal first_instance.object_id, reloaded_instance.object_id,
                 'force_reload should create new instance from file'
  end
end
