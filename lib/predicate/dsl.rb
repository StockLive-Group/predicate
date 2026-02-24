# frozen_string_literal: true

module Predicate
  # Predicate DSL
  #
  # Meta-programming DSL that provides English-like syntax and automatic method
  # generation for predicate definitions.
  #
  # Features::
  # * `method_missing` for predicate definitions
  # * Helper-method delegation (e.g., `is_present?`, `is_blank?`)
  # * Section-based predicate grouping
  # * Auto-generation of predicate methods
  # * Rails validation detection and helper generation
  # * Chainable predicate definitions
  #
  # Usage::
  #   Predicate.define(:assessment) do
  #     has_media { |s| is_present?(s[:media_attachment_ids]) }
  #     has_title { |s| is_present?(s[:title]) }
  #
  #     section :validation do
  #       required_fields { |s| is_present?(s[:name]) && is_present?(s[:email]) }
  #       valid_format    { |s| matches?(s[:email], EMAIL_REGEXP) }
  #     end
  #
  #     wizard_complete { |s| has_media(s) && has_title(s) }
  #   end
  #
  # @author Nauman Tariq
  # @version 1.0.0
  module DSL
    # DSL BUILDER
    # The heart of the DSL - uses method_missing to create an English-like
    # interface for defining predicates with automatic method generation
    #
    # Features:
    # * Direct method definition (no explicit name() calls)
    # * Automatic predicate registration with Core engine
    # * Section-based grouping support
    # * English helper methods delegation
    # * Chainable predicate definitions
    # * Performance optimization via caching
    #
    # Usage:
    #   builder = DSL::Builder.new(:assessment, core_instance)
    #   builder.instance_eval(&block)
    #   builder.build
    class Builder
      attr_reader :entity, :core, :current_section

      def initialize(entity, core = nil, cache_ttl: nil, thread_safe: false)
        @entity = entity.to_sym
        @cache_ttl = cache_ttl
        @thread_safe = thread_safe
        # Create core immediately with parameters (needed for predicate definitions)
        @core = core || Core.new(@entity, cache_ttl: cache_ttl, thread_safe: thread_safe)
        @current_section = nil
        @defined_predicates = {}
      end

      # Build and return the final core instance
      # @return [Predicate::Core] The configured core instance
      def build(_cache_ttl: nil, _thread_safe: false)
        # Core is already created in initialize with correct parameters
        @core
      end

      # Define a section for grouping related predicates
      # @param section_name [Symbol, String] The section name
      # @param block [Proc] Block containing section predicates
      # @example
      #   section :validation do
      #     required_fields { |s| is_present?(s[:name]) && is_present?(s[:email]) }
      #     valid_format { |s| matches?(s[:email], EMAIL_REGEXP) }
      #   end
      def section(section_name, &block)
        raise ArgumentError, 'Section block is required' unless block_given?

        @current_section = section_name.to_sym

        # Create section builder for scoped predicate definitions
        section_builder = SectionBuilder.new(@entity, @core, section_name)
        section_builder.instance_eval(&block)

        @current_section = nil
        self
      end

      # Enable calling existing predicates within new predicate definitions
      # @param predicate_name [Symbol] The predicate name to call
      # @param state [Hash] The state to evaluate
      # @return [Boolean] The predicate result
      def call_predicate(predicate_name, state)
        @core.call(predicate_name, state)
      end

      # Delegate all helper methods to the core instance
      # This enables using helper methods directly in predicate definitions
      def method_missing(method_name, *args, &block)
        # If block is given, this is a predicate definition
        if block_given?
          define_predicate(method_name, &block)
          return self
        end

        # If it's a helper method, delegate to core
        return @core.public_send(method_name, *args) if @core.respond_to?(method_name)

        # If it's a defined predicate being called, execute it
        return call_predicate(method_name, args.first) if args.length == 1 && args.first.is_a?(Hash)

        # Otherwise, raise NoMethodError
        super
      end

      def respond_to_missing?(method_name, include_private = false)
        @core.respond_to?(method_name, include_private) ||
          @defined_predicates.key?(method_name.to_sym) ||
          super
      end

      private

      # Define a predicate and register it with the core
      # @param predicate_name [Symbol] The predicate name
      # @param block [Proc] The predicate logic
      def define_predicate(predicate_name, &block)
        predicate_name = predicate_name.to_sym

        # Store reference for respond_to_missing?
        @defined_predicates[predicate_name] = true

        if @current_section
          # Add to current section
          @core.add_section(@current_section) do |predicates|
            predicates[predicate_name] = block
          end
        else
          # Add as direct predicate
          @core.add_predicate(predicate_name, &block)
        end
      end
    end

    # SECTION BUILDER
    # Specialized builder for section-scoped predicate definitions
    #
    # Features:
    # * Scoped predicate definitions within sections
    # * Automatic section registration
    # * Helper method delegation
    # * Cross-section predicate calling
    #
    # Usage:
    #   section_builder = SectionBuilder.new(:assessment, core, :validation)
    #   section_builder.instance_eval(&block)
    class SectionBuilder
      attr_reader :entity, :core, :section_name

      def initialize(entity, core, section_name)
        @entity = entity.to_sym
        @core = core
        @section_name = section_name.to_sym
        @section_predicates = {}
      end

      # Build the section and register it with the core
      def build
        @core.add_section(@section_name) do |predicates|
          @section_predicates.each do |name, block|
            predicates[name] = block
          end
        end

        @core
      end

      # Enable calling predicates from other sections or direct predicates
      # @param predicate_name [Symbol] The predicate name to call
      # @param state [Hash] The state to evaluate
      # @return [Boolean] The predicate result
      def call_predicate(predicate_name, state)
        @core.call(predicate_name, state)
      end

      # Delegate all helper methods to the core instance
      def method_missing(method_name, *args, &block)
        # If block is given, this is a predicate definition
        if block_given?
          @section_predicates[method_name.to_sym] = block
          build # Rebuild section with new predicate
          return self
        end

        # If it's a helper method, delegate to core
        return @core.public_send(method_name, *args) if @core.respond_to?(method_name)

        # If it's a predicate being called, execute it
        return call_predicate(method_name, args.first) if args.length == 1 && args.first.is_a?(Hash)

        # Otherwise, raise NoMethodError
        super
      end

      def respond_to_missing?(method_name, include_private = false)
        @core.respond_to?(method_name, include_private) ||
          @section_predicates.key?(method_name.to_sym) ||
          super
      end

      private

      # Implement define_predicate for ValidationHelpers compatibility
      # @param name [Symbol] The predicate name
      # @param block [Proc] The predicate logic
      def define_predicate(name, &block)
        @section_predicates[name.to_sym] = block
        build # Rebuild section with new predicate
        self
      end
    end

    # VALIDATION HELPERS
    # Rails-style validation helpers for common predicate patterns
    #
    # Features:
    # * Rails validation pattern detection
    # * Automatic predicate generation from validations
    # * Common validation patterns (presence, format, numericality)
    # * Chainable validation definitions
    #
    # Usage:
    #   builder.validates_presence_of(:name, :email)
    #   builder.validates_format_of(:email, with: EMAIL_REGEXP)
    #   builder.validates_numericality_of(:age, greater_than: 0)
    module ValidationHelpers
      # Generate presence validation predicates
      # @param fields [Array<Symbol>] Fields to validate for presence
      # @example
      #   validates_presence_of(:name, :email)
      #   # Generates: has_name?, has_email?, required_fields?
      def validates_presence_of(*fields)
        fields.each do |field|
          predicate_name = :"has_#{field}"
          define_predicate(predicate_name) do |state|
            @core.is_present?(state[field])
          end
        end

        # Generate combined predicate
        if fields.length > 1
          define_predicate(:required_fields) do |state|
            fields.all? { |field| @core.is_present?(state[field]) }
          end
        end

        self
      end

      # Generate format validation predicates
      # @param field [Symbol] Field to validate
      # @param options [Hash] Validation options
      # @option options [Regexp] :with Pattern to match against
      # @example
      #   validates_format_of(:email, with: EMAIL_REGEXP)
      #   # Generates: valid_email_format?
      def validates_format_of(field, options = {})
        pattern = options[:with]
        raise ArgumentError, 'Pattern (:with) is required' unless pattern

        predicate_name = :"valid_#{field}_format"
        define_predicate(predicate_name) do |state|
          @core.matches?(state[field], pattern)
        end

        self
      end

      # Generate numericality validation predicates
      # @param field [Symbol] Field to validate
      # @param options [Hash] Validation options
      # @option options [Numeric] :greater_than Minimum value (exclusive)
      # @option options [Numeric] :greater_than_or_equal_to Minimum value (inclusive)
      # @option options [Numeric] :less_than Maximum value (exclusive)
      # @option options [Numeric] :less_than_or_equal_to Maximum value (inclusive)
      # @example
      #   validates_numericality_of(:age, greater_than: 0, less_than: 150)
      #   # Generates: valid_age_range?
      def validates_numericality_of(field, options = {})
        predicate_name = :"valid_#{field}"

        define_predicate(predicate_name) do |state|
          value = state[field]
          return false unless value.is_a?(Numeric)

          checks = []
          checks << @core.greater_than?(value, options[:greater_than]) if options[:greater_than]
          if options[:greater_than_or_equal_to]
            checks << @core.greater_than_or_equal_to?(value,
                                                      options[:greater_than_or_equal_to])
          end
          checks << @core.less_than?(value, options[:less_than]) if options[:less_than]
          if options[:less_than_or_equal_to]
            checks << @core.less_than_or_equal_to?(value,
                                                   options[:less_than_or_equal_to])
          end

          checks.all?
        end

        self
      end

      # Generate length validation predicates
      # @param field [Symbol] Field to validate
      # @param options [Hash] Validation options
      # @option options [Integer] :minimum Minimum length
      # @option options [Integer] :maximum Maximum length
      # @option options [Range] :in Length range
      # @example
      #   validates_length_of(:password, minimum: 8, maximum: 128)
      #   # Generates: valid_password_length?
      def validates_length_of(field, options = {})
        predicate_name = :"valid_#{field}_length"

        define_predicate(predicate_name) do |state|
          value = state[field]
          return false unless value.respond_to?(:length)

          length = value.length
          checks = []
          checks << @core.min_length?(value, options[:minimum]) if options[:minimum]
          checks << @core.max_length?(value, options[:maximum]) if options[:maximum]
          checks << @core.in_range?(length, options[:in]) if options[:in]

          checks.all?
        end

        self
      end

      private

      # Define a predicate (to be implemented by including class)
      def define_predicate(name, &block)
        raise NotImplementedError, 'define_predicate must be implemented by including class'
      end
    end

    # Include validation helpers in Builder
    Builder.include(ValidationHelpers)
    SectionBuilder.include(ValidationHelpers)
  end
end
