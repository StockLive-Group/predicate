# frozen_string_literal: true

module Predicate
  # Validation Helpers
  #
  # A collection of pure functions for validating values.
  # These are mixed into Predicate::Core and available in the DSL.
  #
  # Note: Helper names use the +is_+ prefix (e.g. +is_present?+, +is_blank?+)
  # to avoid conflicts with ActiveSupport's +Object#present?+ and +Object#blank?+
  # which are zero-argument methods defined on every object in Rails.
  module Validation
    # Check if a value is present (not nil, not empty, not whitespace-only).
    #
    # Named +is_present?+ to avoid collision with ActiveSupport's +Object#present?+
    # which takes no arguments and checks +self+.
    #
    # @param value [Object] The value to check
    # @return [Boolean] True if value is present (not nil or empty)
    # @example
    #   is_present?("hello")  # => true
    #   is_present?(nil)      # => false
    #   is_present?("")       # => false
    #   is_present?("  ")     # => false
    def is_present?(value)
      return false if value.nil?
      return false if value.respond_to?(:empty?) && value.empty?
      # Handle whitespace-only strings
      return false if value.is_a?(String) && value.strip.empty?

      true
    end

    # Check if a value is blank (nil, empty, or whitespace-only).
    #
    # Named +is_blank?+ to avoid collision with ActiveSupport's +Object#blank?+
    # which takes no arguments and checks +self+.
    #
    # @param value [Object] The value to check
    # @return [Boolean] True if value is blank (nil or empty)
    # @example
    #   is_blank?(nil)     # => true
    #   is_blank?("")      # => true
    #   is_blank?("  ")    # => true
    #   is_blank?("hello") # => false
    def is_blank?(value)
      return true if value.nil?
      return true if value.respond_to?(:empty?) && value.empty?
      # Handle whitespace-only strings
      return true if value.is_a?(String) && value.strip.empty?

      false
    end

    # @param value [Object] The value to check
    # @return [Boolean] True if value is falsy
    def not?(value)
      !value
    end

    # @param value [Object] The value to check
    # @return [Boolean] True if value is truthy
    def truthy?(value)
      !!value
    end

    # @param value [Object] The value to check
    # @return [Boolean] True if value is falsy
    def falsy?(value)
      !value
    end

    # @param value [Object] The value to check
    # @return [Boolean] True if value is a positive number
    def positive?(value)
      value.is_a?(Numeric) && value.positive?
    end

    # @param value [Object] The value to check
    # @return [Boolean] True if value is a negative number
    def negative?(value)
      value.is_a?(Numeric) && value.negative?
    end

    # @param value [Object] The value to check
    # @return [Boolean] True if value is zero
    def zero?(value)
      value.is_a?(Numeric) && value.zero?
    end

    # @param value [Object] The value to check
    # @return [Boolean] True if value is an array with elements
    def has_elements?(value)
      value.is_a?(Array) && !value.empty?
    end

    # @param value [Object] The value to check
    # @return [Boolean] True if value is a hash with keys
    def has_keys?(value)
      value.is_a?(Hash) && !value.empty?
    end

    # @param value [Object] The value to check
    # @param min_length [Integer] Minimum length
    # @return [Boolean] True if value has minimum length
    def min_length?(value, min_length)
      return false unless value.respond_to?(:length)

      value.length >= min_length
    end

    # @param value [Object] The value to check
    # @param max_length [Integer] Maximum length
    # @return [Boolean] True if value has maximum length
    def max_length?(value, max_length)
      return false unless value.respond_to?(:length)

      value.length <= max_length
    end

    # @param value [Object] The value to check
    # @param min [Numeric] Minimum value
    # @return [Boolean] True if value is greater than or equal to min
    def min_value?(value, min)
      return false unless value.is_a?(Numeric)

      value >= min
    end

    # @param value [Object] The value to check
    # @param max [Numeric] Maximum value
    # @return [Boolean] True if value is less than or equal to max
    def max_value?(value, max)
      return false unless value.is_a?(Numeric)

      value <= max
    end

    # @param value [Object] The value to check
    # @param range [Range] The range to check against
    # @return [Boolean] True if value is within range
    def in_range?(value, range)
      return false unless value.is_a?(Numeric)

      range.include?(value)
    end

    # @param value [Object] The value to check
    # @param pattern [Regexp] The pattern to match
    # @return [Boolean] True if value matches pattern
    def matches?(value, pattern)
      return false unless value.respond_to?(:match)

      !value.match(pattern).nil?
    end

    # @param value [Object] The value to check
    # @param type [Class] The type to check against
    # @return [Boolean] True if value is of the specified type
    def is_type?(value, type)
      value.is_a?(type)
    end

    # @param value [Object] The value to check
    # @param types [Array<Class>] The types to check against
    # @return [Boolean] True if value is one of the specified types
    def is_one_of?(value, types)
      types.any? { |type| value.is_a?(type) }
    end

    # @param value [Object] The value to check
    # @param values [Array] The values to check against
    # @return [Boolean] True if value is one of the specified values
    def is_one_of_values?(value, values)
      values.include?(value)
    end

    # @param value [Object] The value to check
    # @param values [Array, Enumerable] The values to check against
    # @return [Boolean] True if value is not one of the specified values
    def is_not_one_of_values?(value, values)
      # Guard against nil
      return true if values.nil?

      # Guard against non-collection types (String has include? but for substring search)
      return true unless values.is_a?(Enumerable) || values.is_a?(Range)

      !values.include?(value)
    rescue StandardError
      # If anything goes wrong, treat as not included
      true
    end

    # @param value [Object] The value to check
    # @param other [Object] The other value to compare
    # @return [Boolean] True if values are equal
    def equal_to?(value, other)
      value == other
    end

    # @param value [Object] The value to check
    # @param other [Object] The other value to compare
    # @return [Boolean] True if values are not equal
    def not_equal_to?(value, other)
      value != other
    end

    # @param value [Object] The value to check
    # @param other [Object] The other value to compare
    # @return [Boolean] True if value is greater than other
    def greater_than?(value, other)
      return false unless value.is_a?(Numeric) && other.is_a?(Numeric)

      value > other
    end

    # @param value [Object] The value to check
    # @param other [Object] The other value to compare
    # @return [Boolean] True if value is less than other
    def less_than?(value, other)
      return false unless value.is_a?(Numeric) && other.is_a?(Numeric)

      value < other
    end

    # @param value [Object] The value to check
    # @param other [Object] The other value to compare
    # @return [Boolean] True if value is greater than or equal to other
    def greater_than_or_equal_to?(value, other)
      return false unless value.is_a?(Numeric) && other.is_a?(Numeric)

      value >= other
    end

    # @param value [Object] The value to check
    # @param other [Object] The other value to compare
    # @return [Boolean] True if value is less than or equal to other
    def less_than_or_equal_to?(value, other)
      return false unless value.is_a?(Numeric) && other.is_a?(Numeric)

      value <= other
    end
  end
end
