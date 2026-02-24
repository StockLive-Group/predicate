# frozen_string_literal: true

module Predicate
  # Model Integration
  #
  # Auto-definition pattern for seamless model integration.
  #
  # Features::
  # * Automatic predicate method generation
  # * Inclusion helpers powered by `method_missing`
  # * Predicate file auto-loading (`app/predicates/*_predicate.rb`)
  # * Rails integration without requiring `ActiveSupport::Concern`
  # * Lazy loading for better boot times
  # * Cache invalidation helpers
  # * Graceful error handling
  #
  # Usage::
  #   class Assessment < ApplicationRecord
  #     include Predicate::ModelIntegration
  #     # Auto-loads app/predicates/assessment_predicate.rb
  #   end
  #
  #   assessment.has_media?
  #   assessment.wizard_complete?
  #
  # @author Nauman Tariq
  # @version 1.0.0
  module ModelIntegration
    # Include class methods and auto-load predicates from app/predicates/.
    # Models only need a single line: +include Predicate::ModelIntegration+
    # The predicate file is resolved by convention from the model name
    # (e.g. +LivestockType+ loads +app/predicates/livestock_type_predicate.rb+).
    def self.included(base)
      base.extend(ClassMethods)
      base.load_predicates!
    end

    # CLASS METHODS
    # Class-level methods for predicate management and configuration
    module ClassMethods
      # Get the predicate instance for this model
      # @return [Predicate::Core, nil] The predicate instance or nil if not loaded
      def predicate_instance
        @predicate_instance
      end

      # Load predicates for this model
      # @param force_reload [Boolean] Force reload even if already loaded
      # @return [Predicate::Core] The loaded predicate instance
      def load_predicates!(force_reload: false)
        return @predicate_instance if @predicate_instance && !force_reload

        # model_name may not be available during class definition
        # (e.g. Class.new blocks where methods are defined after include).
        # Predicates will be lazy-loaded on first use via method_missing.
        return nil unless respond_to?(:model_name)

        # Extract entity name flexibly from different model_name types
        entity_name = extract_entity_name(model_name)

        # Return nil if we couldn't determine entity name
        return nil if entity_name.nil?

        # If force_reload, try loading from file first to pick up changes
        if force_reload
          predicate_file = predicate_file_path(entity_name)

          if File.exist?(predicate_file)
            begin
              # Clear registry entry to force fresh load
              Registry.unregister(entity_name) if Registry.respond_to?(:unregister)

              # Load the predicate file (will re-register)
              load predicate_file
              @predicate_instance = Predicate.for(entity_name)
              return @predicate_instance
            rescue StandardError => e
              if defined?(Rails) && Rails.respond_to?(:logger)
                Rails.logger.warn "Failed to reload predicates for #{entity_name}: #{e.message}"
              end
              # Fall through to registry check
            end
          end
        end

        # Check if predicates are already in the registry (for testing/programmatic usage)
        begin
          @predicate_instance = Predicate.for(entity_name)
          return @predicate_instance
        rescue KeyError
          # Predicates not in registry, try loading from file
        end

        predicate_file = predicate_file_path(entity_name)

        if File.exist?(predicate_file)
          begin
            # Load the predicate file
            load predicate_file
            @predicate_instance = Predicate.for(entity_name)
          rescue StandardError => e
            if defined?(Rails) && Rails.respond_to?(:logger)
              Rails.logger.warn "Failed to load predicates for #{entity_name}: #{e.message}"
            end
            @predicate_instance = nil
          end
        else
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.debug { "No predicate file found for #{entity_name} at #{predicate_file}" }
          end
          @predicate_instance = nil
        end

        @predicate_instance
      end

      # Check if predicates are loaded for this model
      # @return [Boolean] True if predicates are loaded
      def predicates_loaded?
        !@predicate_instance.nil?
      end

      # Clear cached predicates for this model
      def clear_predicates!
        @predicate_instance = nil
      end

      # Get all available predicate names for this model
      # @return [Array<Symbol>] Array of predicate names
      def predicate_names
        load_predicates!
        @predicate_instance&.predicate_names || []
      end

      # Check if a predicate exists for this model
      # @param predicate_name [Symbol, String] The predicate name
      # @return [Boolean] True if predicate exists
      def predicate?(predicate_name)
        load_predicates!
        @predicate_instance&.predicate?(predicate_name) || false
      end

      private

      # Extract entity name from different model_name types
      # Handles Rails ActiveModel::Name, OpenStruct, String, Symbol, etc.
      # @param model_name [Object] The model name object
      # @return [Symbol, nil] The entity name as a symbol, or nil if invalid
      # @example
      #   extract_entity_name(:user)                    # => :user
      #   extract_entity_name("User")                   # => :user
      #   extract_entity_name(User.model_name)          # => :user (Rails)
      #   extract_entity_name(OpenStruct.new(underscore: 'user')) # => :user
      def extract_entity_name(model_name)
        return nil if model_name.nil?
        return model_name if model_name.is_a?(Symbol)
        return model_name.param_key.to_sym if model_name.respond_to?(:param_key)

        if model_name.respond_to?(:underscore)
          model_name.underscore.to_sym
        else
          # Use Util.underscore if ActiveSupport not available
          Util.underscore(model_name.to_s).to_sym
        end
      end

      # Get the predicate file path for a given entity
      # @param entity_name [Symbol, String] The entity name
      # @return [String] The full path to the predicate file
      def predicate_file_path(entity_name)
        if defined?(Rails) && Rails.respond_to?(:root)
          Rails.root.join('app', 'predicates', "#{entity_name}_predicate.rb").to_s
        else
          File.join(Dir.pwd, 'app', 'predicates', "#{entity_name}_predicate.rb")
        end
      end
    end

    # INSTANCE METHODS
    # Instance-level methods for predicate evaluation and model integration

    # Get the predicate instance for this model instance
    # @return [Predicate::Core, nil] The predicate instance or nil if not loaded
    def predicate_instance
      self.class.predicate_instance
    end

    # Load predicates for this model instance
    # @return [Predicate::Core] The loaded predicate instance
    def load_predicates!
      self.class.load_predicates!
    end

    # Check if predicates are loaded for this model instance
    # @return [Boolean] True if predicates are loaded
    def predicates_loaded?
      self.class.predicates_loaded?
    end

    # Get all available predicate names for this model instance
    # @return [Array<Symbol>] Array of predicate names
    def predicate_names
      self.class.predicate_names
    end

    # Check if a predicate exists for this model instance
    # @param predicate_name [Symbol, String] The predicate name
    # @return [Boolean] True if predicate exists
    def predicate?(predicate_name)
      self.class.predicate?(predicate_name)
    end

    # Call a predicate with this instance's state
    # @param predicate_name [Symbol, String] The predicate name
    # @param additional_state [Hash] Additional state to merge
    # @return [Boolean] The predicate result
    def call_predicate(predicate_name, additional_state = {})
      return false unless predicates_loaded?

      predicate_instance = self.class.predicate_instance
      return false unless predicate_instance

      state = build_state_hash(additional_state)
      predicate_instance.call(predicate_name, state)
    end

    # Get predicate statistics for this instance
    # @return [Hash] Predicate performance statistics
    def predicate_stats
      load_predicates!
      predicate_instance = self.class.predicate_instance
      predicate_instance&.performance_stats || {}
    end

    # Clear predicate cache for this instance
    def clear_predicate_cache!
      load_predicates!
      predicate_instance = self.class.predicate_instance
      predicate_instance&.clear_cache!
    end

    # Handle missing predicate methods
    # @param method_name [Symbol] The method name
    # @param args [Array] Method arguments
    # @return [Boolean] The predicate result
    def method_missing(method_name, *args)
      # Check if this looks like a predicate method (ends with ?)
      if method_name.to_s.end_with?('?') && args.empty?
        predicate_name = method_name.to_s.chomp('?').to_sym

        # Lazy-load predicates on first use if not yet loaded
        load_predicates! unless predicates_loaded?

        # Only try to call if predicates are loaded and predicate exists
        if predicates_loaded? && predicate?(predicate_name)
          call_predicate(predicate_name)
        else
          # Predicate doesn't exist or not loaded, return false for predicate methods
          false
        end
      else
        # Not a predicate method, call super
        super
      end
    end

    # Check if this instance responds to a method
    # @param method_name [Symbol] The method name
    # @param include_private [Boolean] Include private methods
    # @return [Boolean] True if responds to method
    def respond_to_missing?(method_name, include_private = false)
      # Check if this looks like a predicate method
      if method_name.to_s.end_with?('?')
        predicate_name = method_name.to_s.chomp('?').to_sym
        # Only return true if predicates are loaded AND the predicate exists
        return predicate?(predicate_name) if predicates_loaded?

        return false

      end

      super
    end

    private

    # Build a state hash from this instance's attributes
    # @param additional_state [Hash] Additional state to merge
    # @return [Hash] The complete state hash
    def build_state_hash(additional_state = {})
      # Start with attributes if available
      state = extract_base_state

      # Stringify keys for consistency then symbolize
      # This handles both string and symbol keys in attributes
      state = state.transform_keys(&:to_sym)

      # Merge additional state
      state.merge!(additional_state) if additional_state

      state
    end

    def extract_base_state
      if respond_to?(:attributes) && attributes.is_a?(Hash)
        base_state = attributes.dup
        Rails.logger.debug { "DEBUG: Model attributes: #{base_state.inspect}" } if defined?(Rails) && Rails.respond_to?(:logger)
        base_state
      elsif respond_to?(:to_h)
        base_state = to_h.dup
        Rails.logger.debug { "DEBUG: Model to_h: #{base_state.inspect}" } if defined?(Rails) && Rails.respond_to?(:logger)
        base_state
      else
        # Fallback to instance variables
        base_state = instance_variables.each_with_object({}) do |var, hash|
          hash[var.to_s.delete('@').to_sym] = instance_variable_get(var)
        end
        Rails.logger.debug { "DEBUG: Model instance variables: #{base_state.inspect}" } if defined?(Rails) && Rails.respond_to?(:logger)
        base_state
      end
    end

    # PREDICATE FILE GENERATOR
    # Utility for generating predicate files from model analysis
    module PredicateFileGenerator
      # Generate a predicate file for a model
      # @param model_class [Class] The model class
      # @param output_path [String] The output path (optional)
      # @return [String] The generated predicate file content
      def self.generate_for_model(model_class, output_path = nil)
        # Use ActiveSupport::Inflector if available, otherwise basic conversion
        entity_name = if model_class.name.respond_to?(:underscore)
                        model_class.name.underscore.to_sym
                      else
                        # Try to require ActiveSupport, fall back to basic conversion
                        # if not available
                        begin
                          require 'active_support/inflector'
                          ActiveSupport::Inflector.underscore(model_class.name).to_sym
                        rescue LoadError
                          # Basic snake_case conversion without ActiveSupport
                          Util.underscore(model_class.name).to_sym
                        end
                      end

        predicate_content = generate_predicate_content(model_class, entity_name)

        if output_path
          File.write(output_path, predicate_content)
          # Only log if Rails is available
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.debug { "Generated predicate file: #{output_path}" }
          end
        end

        predicate_content
      end

      # Generate predicate content based on model analysis
      # @param model_class [Class] The model class
      # @param entity_name [Symbol] The entity name
      # @return [String] The generated predicate content
      def self.generate_predicate_content(model_class, entity_name)
        content = []
        content << '# frozen_string_literal: true'
        content << ''
        content << "# Auto-generated predicate file for #{model_class.name}"
        # Use Time.now if Time.zone not available
        timestamp = Predicate::Util.now
        content << "# Generated on: #{timestamp}"
        content << ''
        content << "Predicate.define(:#{entity_name}) do"
        content << '  # TODO: Add your predicates here'
        content << '  # Example predicates based on model analysis:'
        content << ''

        content += generate_attribute_predicates(model_class)
        content += generate_association_predicates(model_class)

        content << '  # Add custom predicates below:'
        content << '  # wizard_complete { |s| has_title(s) && has_description(s) }'
        content << 'end'
        content << ''

        content.join("\n")
      end

      def self.generate_attribute_predicates(model_class)
        return [] unless model_class.respond_to?(:attribute_names)

        model_class.attribute_names.map do |attr|
          next if %w[id created_at updated_at].include?(attr.to_s)

          "  has_#{attr} { |s| is_present?(s[:#{attr}]) }"
        end.compact
      end

      def self.generate_association_predicates(model_class)
        return [] unless model_class.respond_to?(:reflect_on_all_associations)

        model_class.reflect_on_all_associations.map do |assoc|
          "  has_#{assoc.name} { |s| is_present?(s[:#{assoc.name}]) }"
        end
      end
    end

    # Include the generator in the main module
    extend PredicateFileGenerator
  end
end
