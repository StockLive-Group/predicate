# frozen_string_literal: true

module Predicate
  # General Utility Methods
  module Util
    module_function

    # Basic underscore conversion for class names (without ActiveSupport)
    # @param class_name [String] The class name to convert
    # @return [String] The underscored version
    # @example
    #   underscore("UserAccount") # => "user_account"
    #   underscore("API") # => "api"
    def underscore(class_name)
      return class_name unless class_name

      name = class_name.to_s.dup
      # Replace :: with /
      name.gsub!('::', '/')
      # Insert underscore before uppercase letters that follow lowercase letters
      name.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      # Insert underscore before uppercase letters that are followed by lowercase letters
      name.gsub!(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      # Convert to lowercase
      name.downcase
    end

    # Get current time
    # @return [Time, ActiveSupport::TimeWithZone] Current time
    def now
      return ::Time.zone.now if defined?(::Time.zone) && ::Time.zone

      ::Time.now
    end
  end
end
