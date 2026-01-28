# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-28

### Added
- Initial release as standalone gem
- Pure boolean predicate DSL with method_missing syntax
- Automatic memoization with SHA256-based cache keys
- TTL (time-to-live) cache expiration support
- Thread-safe operations via optional Mutex
- LRU cache eviction (1000 entry limit)
- Logical combinators: `all_of`, `any_of`, `none_of`, `not_predicate`
- Conditional combinators: `when_present`, `when_blank`
- Section-based predicate grouping
- Rails model integration via `Predicate::ModelIntegration`
- Railtie for automatic Rails integration
- Performance monitoring and statistics
- 27 English-like validation helpers
- Rails validation pattern generators
- Predicate file generator for models
- Comprehensive test suite (183 runs, 508 assertions)

### Changed
- Extracted from StockLive codebase into standalone gem
- Fixed Zeitwerk compatibility (proper gem directory structure)
- Removed Rails-specific Rubocop directives for broader compatibility

### Fixed
- Cache collision issues with SHA256-based keys
- Section predicate caching consistency
- Thread-safety for concurrent environments
