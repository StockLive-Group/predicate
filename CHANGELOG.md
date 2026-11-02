# Changelog

All notable changes to this project will be documented in this file. The release
workflow refuses to publish a version with no entry — see RELEASING.md.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-24

First public release on RubyGems, as `predicate-rb` (the name `predicate`
belongs to an unrelated gem). `require "predicate"` and the `Predicate`
constant are unchanged; `lib/predicate-rb.rb` only requires `predicate`, so
`Bundler.require` works with `gem "predicate-rb"`.

### Changed
- **Breaking:** the validation helpers `present?(value)` and `blank?(value)` are
  renamed `is_present?(value)` and `is_blank?(value)`. Under Rails, Active
  Support defines zero-argument `Object#present?`/`#blank?`, which Ruby found
  before `method_missing`; the call raised `ArgumentError` and the predicate
  silently returned `false`.
- Including `Predicate::ModelIntegration` loads the model's predicate file by
  naming convention; models no longer call `load_predicates!` explicitly.

### Fixed
- `method_missing` lazy-loads definitions, so a predicate called before its file
  was loaded no longer reports as undefined.

## [1.1.0] - 2026-02-09

### Fixed
- Rails: predicate definition files are ignored by Zeitwerk instead of being
  added to `autoload_paths`, so they register without having to define a
  constant matching their filename.

## [1.0.0] - 2026-01-28

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
