# frozen_string_literal: true

require_relative 'predicate/version'
require_relative 'predicate/validation'
require_relative 'predicate/util'
require_relative 'predicate/core'
require_relative 'predicate/dsl'
require_relative 'predicate/combinators'
require_relative 'predicate/model_integration'

# Predicate Library
#
# A super-thin, meta-programming-powered predicate library for Rails.
#
# Features::
# * Pure boolean logic (true/false)
# * Meta-programming DSL with `method_missing`
# * Automatic memoization and caching
# * Rails auto-detection (validations, scopes, associations)
# * Section-based predicate grouping
# * English-like helper methods (`present?`, `blank?`, `not?`)
# * Performance monitoring and statistics
# * Model auto-definition with `method_missing`
#
# Usage::
#   Predicate.define(:assessment) do
#     has_media { |s| s[:media_attachment_ids].present? }
#     wizard_complete { |s| has_media(s) && has_title(s) }
#   end
#
# @author Nauman Tariq
# @version 1.0.0

module Predicate
  # Custom exception for predicate-related errors
  class InvalidPredicate < StandardError; end

  # Main entry point for defining predicates
  # @param entity [Symbol, String] The entity name (e.g., :assessment, :sale)
  # @param cache_ttl [Numeric, nil] Cache time-to-live in seconds (nil = no expiration)
  # @param thread_safe [Boolean] Enable thread-safe cache operations (default: false)
  # @param block [Proc] Block containing predicate definitions
  # @return [Predicate::Core] The predicate instance
  # @example
  #   Predicate.define(:assessment) do
  #     has_media { |s| present?(s[:media_attachment_ids]) }
  #     wizard_complete { |s| has_media(s) && has_title(s) }
  #   end
  # @example With TTL
  #   Predicate.define(:assessment, cache_ttl: 5.minutes) do
  #     has_media { |s| present?(s[:media_attachment_ids]) }
  #   end
  # @example With thread-safety
  #   Predicate.define(:assessment, thread_safe: true, cache_ttl: 5.minutes) do
  #     has_media { |s| present?(s[:media_attachment_ids]) }
  #   end
  def self.define(entity, cache_ttl: nil, thread_safe: false, &block)
    builder = DSL::Builder.new(entity, nil, cache_ttl: cache_ttl, thread_safe: thread_safe)
    builder.instance_eval(&block)
    core = builder.build
    Registry.register(entity, core)
    core
  end

  # Get predicate instance for a given entity
  # @param entity [Symbol, String] The entity name
  # @return [Predicate::Core] The predicate instance
  # @raise [KeyError] If no predicate is defined for the entity
  # @example
  #   assessment_predicates = Predicate.for(:assessment)
  #   assessment_predicates.call(:has_media, { media_attachment_ids: [1] })
  def self.for(entity)
    Registry.fetch(entity)
  end

  # Clear all predicate caches across the registry
  # @example
  #   Predicate.clear_cache!
  def self.clear_cache!
    Registry.clear_cache!
  end

  # Clear all registered predicates from the registry
  # @example
  #   Predicate.clear_registry!
  def self.clear_registry!
    Registry.clear_registry!
  end

  # REGISTRY
  # Central registry for storing and managing predicate instances
  #
  # Responsibilities:
  # * Store predicate instances by entity name
  # * Provide lookup and retrieval methods
  # * Manage cache invalidation across all predicates
  # * Track registry statistics and performance metrics
  # * Handle predicate lifecycle management
  #
  # Usage:
  #   registry = Predicate::Registry.new
  #   registry.register(:assessment, predicate_instance)
  #   predicate = registry.fetch(:assessment)
  #   stats = registry.stats
  class Registry
    def initialize
      @predicates = {}
    end

    # Register a predicate instance for an entity
    # @param entity [Symbol, String] The entity name
    # @param predicate_instance [Predicate::Core] The predicate instance
    def register(entity, predicate_instance)
      @predicates[entity.to_sym] = predicate_instance
    end

    # Fetch a predicate instance for an entity
    # @param entity [Symbol, String] The entity name
    # @return [Predicate::Core] The predicate instance
    # @raise [KeyError] If no predicate is defined for the entity
    def fetch(entity)
      @predicates.fetch(entity.to_sym) { raise KeyError, "No predicate for #{entity}" }
    end

    # Unregister a predicate instance for an entity
    # @param entity [Symbol, String] The entity name
    # @return [Predicate::Core, nil] The removed predicate instance or nil
    def unregister(entity)
      @predicates.delete(entity.to_sym)
    end

    # Class method to register a predicate instance
    # @param entity [Symbol, String] The entity name
    # @param predicate_instance [Predicate::Core] The predicate instance
    def self.register(entity, predicate_instance)
      Predicate.registry.register(entity, predicate_instance)
    end

    # Class method to fetch a predicate instance
    # @param entity [Symbol, String] The entity name
    # @return [Predicate::Core] The predicate instance
    def self.fetch(entity)
      Predicate.registry.fetch(entity)
    end

    # Class method to unregister a predicate instance
    # @param entity [Symbol, String] The entity name
    # @return [Predicate::Core, nil] The removed predicate instance or nil
    def self.unregister(entity)
      Predicate.registry.unregister(entity)
    end

    # Clear caches for all registered predicate instances
    def self.clear_cache!
      Predicate.registry.instance_variable_get(:@predicates).each_value(&:clear_cache!)
    end

    # Clear all registered predicates from the registry
    def self.clear_registry!
      Predicate.registry.instance_variable_set(:@predicates, {})
    end
  end

  # Default registry instance
  def self.registry
    @registry ||= Registry.new
  end

  # Include combinators in DSL after all files are loaded
  DSL::Builder.include(Combinators::Helpers)
  DSL::SectionBuilder.include(Combinators::Helpers)

  # PERFORMANCE MONITORING
  # Performance tracking and monitoring utilities for predicates
  #
  # Features:
  # * Track predicate execution times
  # * Monitor cache hit/miss ratios
  # * Collect performance statistics
  # * Rails cache integration for metrics storage
  # * Performance bottleneck identification
  #
  # Usage:
  #   Predicate::Performance.track(:has_media, 0.001)
  #   stats = Predicate::Performance.stats(:has_media)
  module Performance
    @stats = {}
    @mutex = Mutex.new

    # Track predicate execution time
    # @param predicate_name [Symbol] The predicate name
    # @param duration [Float] Execution time in seconds
    # @example
    #   Predicate::Performance.track(:has_media, 0.001)
    def self.track(predicate_name, duration)
      @mutex.synchronize do
        @stats[predicate_name] ||= {
          total_calls: 0,
          total_time: 0.0,
          avg_time: 0.0,
          cache_hits: 0,
          cache_misses: 0
        }
        stats = @stats[predicate_name]
        stats[:total_calls] += 1
        stats[:total_time] += duration
        stats[:avg_time] = stats[:total_time] / stats[:total_calls]
      end

      # Log if Rails is available
      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.debug { "Predicate #{predicate_name} executed in #{duration} seconds" }
      end
    end

    # Track cache hit
    # @param predicate_name [Symbol] The predicate name
    def self.track_cache_hit(predicate_name)
      @mutex.synchronize do
        @stats[predicate_name] ||= {
          total_calls: 0,
          total_time: 0.0,
          avg_time: 0.0,
          cache_hits: 0,
          cache_misses: 0
        }
        @stats[predicate_name][:cache_hits] += 1
      end

      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.debug { "Predicate #{predicate_name} cache hit" }
      end
    end

    # Track cache miss
    # @param predicate_name [Symbol] The predicate name
    def self.track_cache_miss(predicate_name)
      @mutex.synchronize do
        @stats[predicate_name] ||= {
          total_calls: 0,
          total_time: 0.0,
          avg_time: 0.0,
          cache_hits: 0,
          cache_misses: 0
        }
        @stats[predicate_name][:cache_misses] += 1
      end

      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.debug { "Predicate #{predicate_name} cache miss" }
      end
    end

    # Get performance statistics for a predicate
    # @param predicate_name [Symbol] The predicate name
    # @return [Hash] Performance statistics (e.g., total_calls, total_time, avg_time)
    def self.stats(predicate_name)
      @mutex.synchronize do
        @stats[predicate_name] || {
          total_calls: 0,
          total_time: 0.0,
          avg_time: 0.0,
          cache_hits: 0,
          cache_misses: 0
        }
      end
    end

    # Reset statistics (useful for testing)
    def self.reset!
      @mutex.synchronize do
        @stats = {}
      end
    end
  end
end

# Load Railtie if Rails is present
require_relative 'predicate/railtie' if defined?(Rails::Railtie)
