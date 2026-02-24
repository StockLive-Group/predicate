# frozen_string_literal: true

module Predicate
  # Predicate Combinators
  #
  # Logical operators and combinators for creating complex predicate logic.
  #
  # Features::
  # * AND/OR/NOT helpers
  # * Chainable predicate combinations
  # * Short-circuit evaluation
  # * Nested predicate composition
  # * English-like helpers (`all_of`, `any_of`, `none_of`)
  # * Conditional predicates (`when_present`, `when_blank`)
  #
  # Usage::
  #   Predicate.define(:assessment) do
  #     has_media        { |s| is_present?(s[:media_attachment_ids]) }
  #     has_title        { |s| is_present?(s[:title]) }
  #     has_description  { |s| is_present?(s[:description]) }
  #
  #     content_ready { |s| all_of(:has_title, :has_description).call(s) }
  #     any_content   { |s| any_of(:has_title, :has_description).call(s) }
  #     not_empty     { |s| not_predicate(:has_media).call(s) }
  #   end
  #
  # @author Nauman Tariq
  # @version 1.0.0
  module Combinators
    # COMBINATOR BASE
    # Base class for all combinators providing common functionality
    #
    # Features:
    # * Predicate resolution and execution
    # * Error handling and graceful fallbacks
    # * Performance tracking and caching
    # * Core integration for helper methods
    class Base
      attr_reader :core

      def initialize(core)
        @core = core
      end

      # Call the combinator with a state
      # @param state [Hash] The state to evaluate
      # @return [Boolean] The result of the combination
      def call(state)
        raise NotImplementedError, 'Combinator must implement #call'
      end

      private

      # Resolve a predicate reference to an actual callable
      # @param predicate [Symbol, String, Proc, Combinator] The predicate reference
      # @return [Proc] The callable predicate
      def resolve_predicate(predicate)
        case predicate
        when Symbol, String, Proc, Base
          # Store the symbol/string for lazy resolution or handle combinator objects
          predicate
        else
          raise ArgumentError, "Invalid predicate type: #{predicate.class}"
        end
      end

      # Resolve and execute a predicate (lazy resolution)
      # @param predicate [Symbol, String, Proc, Combinator] The predicate to execute
      # @param state [Hash] The state to pass to the predicate
      # @return [Boolean] The result of the predicate
      def resolve_and_execute(predicate, state)
        case predicate
        when Symbol, String
          @core.call(predicate.to_sym, state)
        when Proc, Base
          # Handle combinator objects and procs
          predicate.call(state)
        else
          raise ArgumentError, "Invalid predicate type: #{predicate.class}"
        end
      rescue StandardError => e
        Rails.logger.error "Combinator predicate failed: #{e.message}" if defined?(Rails) && Rails.respond_to?(:logger)
        false
      end

      # Execute a predicate safely with error handling
      # @param predicate [Proc] The predicate to execute
      # @param state [Hash] The state to pass to the predicate
      # @return [Boolean] The result of the predicate
      def execute_predicate(predicate, state)
        predicate.call(state)
      rescue StandardError => e
        Rails.logger.error "Combinator predicate failed: #{e.message}" if defined?(Rails) && Rails.respond_to?(:logger)
        false
      end
    end

    # ALL_OF (AND)
    # Logical AND combinator - all predicates must return true
    #
    # Features:
    # * Short-circuit evaluation (stops on first false)
    # * Performance optimization for large predicate lists
    # * Error handling with graceful fallbacks
    #
    # Usage:
    #   all_of(:has_title, :has_description, :has_media).call(state)
    class AllOf < Base
      def initialize(core, *predicates)
        super(core)
        @predicates = predicates.map { |p| resolve_predicate(p) }
        raise ArgumentError, 'At least one predicate is required' if @predicates.empty?
      end

      # Execute all predicates with AND logic (short-circuit on false)
      # @param state [Hash] The state to evaluate
      # @return [Boolean] True if all predicates return true
      def call(state)
        @predicates.all? { |predicate| resolve_and_execute(predicate, state) }
      end
    end

    # ANY_OF (OR)
    # Logical OR combinator - at least one predicate must return true
    #
    # Features:
    # * Short-circuit evaluation (stops on first true)
    # * Performance optimization for large predicate lists
    # * Error handling with graceful fallbacks
    #
    # Usage:
    #   any_of(:has_title, :has_description, :has_media).call(state)
    class AnyOf < Base
      def initialize(core, *predicates)
        super(core)
        @predicates = predicates.map { |p| resolve_predicate(p) }
        raise ArgumentError, 'At least one predicate is required' if @predicates.empty?
      end

      # Execute all predicates with OR logic (short-circuit on true)
      # @param state [Hash] The state to evaluate
      # @return [Boolean] True if any predicate returns true
      def call(state)
        @predicates.any? { |predicate| resolve_and_execute(predicate, state) }
      end
    end

    # NONE_OF (NOR)
    # Logical NOR combinator - none of the predicates should return true
    #
    # Features:
    # * Short-circuit evaluation (stops on first true)
    # * Performance optimization for large predicate lists
    # * Error handling with graceful fallbacks
    #
    # Usage:
    #   none_of(:has_errors, :is_invalid, :is_expired).call(state)
    class NoneOf < Base
      def initialize(core, *predicates)
        super(core)
        @predicates = predicates.map { |p| resolve_predicate(p) }
        raise ArgumentError, 'At least one predicate is required' if @predicates.empty?
      end

      # Execute all predicates with NOR logic (none should be true)
      # @param state [Hash] The state to evaluate
      # @return [Boolean] True if none of the predicates return true
      def call(state)
        @predicates.none? { |predicate| resolve_and_execute(predicate, state) }
      end
    end

    # NOT
    # Logical NOT combinator - negates a single predicate
    #
    # Features:
    # * Simple negation of any predicate
    # * Error handling with graceful fallbacks
    # * Support for symbol, string, and proc predicates
    #
    # Usage:
    #   not(:has_errors).call(state)
    class Not < Base
      def initialize(core, predicate)
        super(core)
        @predicate = resolve_predicate(predicate)
      end

      # Execute predicate and negate the result
      # @param state [Hash] The state to evaluate
      # @return [Boolean] The negated result of the predicate
      def call(state)
        !resolve_and_execute(@predicate, state)
      end
    end

    # WHEN_PRESENT
    # Conditional combinator - only evaluates predicate when field is present
    #
    # Features:
    # * Conditional evaluation based on field presence
    # * Prevents errors when evaluating empty/nil fields
    # * Customizable default return value
    #
    # Usage:
    #   when_present(:title) { |s| min_length?(s[:title], 3) }.call(state)
    class WhenPresent < Base
      def initialize(core, field, default_value: true, &predicate)
        super(core)
        @field = field.to_sym
        @predicate = predicate
        @default_value = default_value
        raise ArgumentError, 'Predicate block is required' unless @predicate
      end

      # Execute predicate only when field is present
      # @param state [Hash] The state to evaluate
      # @return [Boolean] The result of the predicate or default value
      def call(state)
        return @default_value unless @core.is_present?(state[@field])

        resolve_and_execute(@predicate, state)
      end
    end

    # WHEN_BLANK
    # Conditional combinator - only evaluates predicate when field is blank
    #
    # Features:
    # * Conditional evaluation based on field absence
    # * Useful for default value logic
    # * Customizable default return value
    #
    # Usage:
    #   when_blank(:title) { |s| has_default_title?(s) }.call(state)
    class WhenBlank < Base
      def initialize(core, field, default_value: false, &predicate)
        super(core)
        @field = field.to_sym
        @predicate = predicate
        @default_value = default_value
        raise ArgumentError, 'Predicate block is required' unless @predicate
      end

      # Execute predicate only when field is blank
      # @param state [Hash] The state to evaluate
      # @return [Boolean] The result of the predicate or default value
      def call(state)
        return @default_value unless @core.is_blank?(state[@field])

        resolve_and_execute(@predicate, state)
      end
    end

    # COMBINATOR HELPERS
    # Helper methods for creating combinators with English-like syntax
    #
    # These are mixed into the DSL Builder to provide a natural syntax
    module Helpers
      # Create an ALL_OF combinator (logical AND)
      # @param predicates [Array<Symbol, String, Proc>] Predicates to combine
      # @return [AllOf] The combinator instance
      # @example
      #   all_of(:has_title, :has_description)
      def all_of(*predicates)
        AllOf.new(@core, *predicates)
      end

      # Create an ANY_OF combinator (logical OR)
      # @param predicates [Array<Symbol, String, Proc>] Predicates to combine
      # @return [AnyOf] The combinator instance
      # @example
      #   any_of(:has_title, :has_description)
      def any_of(*predicates)
        AnyOf.new(@core, *predicates)
      end

      # Create a NONE_OF combinator (logical NOR)
      # @param predicates [Array<Symbol, String, Proc>] Predicates to combine
      # @return [NoneOf] The combinator instance
      # @example
      #   none_of(:has_errors, :is_invalid)
      def none_of(*predicates)
        NoneOf.new(@core, *predicates)
      end

      # Create a NOT combinator (logical NOT)
      # @param predicate [Symbol, String, Proc] Predicate to negate
      # @return [Not] The combinator instance
      # @example
      #   not_predicate(:has_errors)
      def not_predicate(predicate)
        Not.new(@core, predicate)
      end

      # Alias for backwards compatibility, but avoid 'not' keyword
      alias negate not_predicate

      # Create a WHEN_PRESENT combinator
      # @param field [Symbol, String] Field to check for presence
      # @param default_value [Boolean] Default value when field is not present
      # @param block [Proc] Predicate to execute when field is present
      # @return [WhenPresent] The combinator instance
      # @example
      #   when_present(:title) { |s| min_length?(s[:title], 3) }
      def when_present(field, default_value: true, &block)
        WhenPresent.new(@core, field, default_value: default_value, &block)
      end

      # Create a WHEN_BLANK combinator
      # @param field [Symbol, String] Field to check for blankness
      # @param default_value [Boolean] Default value when field is not blank
      # @param block [Proc] Predicate to execute when field is blank
      # @return [WhenBlank] The combinator instance
      # @example
      #   when_blank(:title) { |s| has_default_title?(s) }
      def when_blank(field, default_value: false, &block)
        WhenBlank.new(@core, field, default_value: default_value, &block)
      end
    end
  end
end
