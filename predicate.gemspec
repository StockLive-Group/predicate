# frozen_string_literal: true

require_relative 'lib/predicate/version'

Gem::Specification.new do |spec|
  # The RubyGems name differs from the library name: `predicate` on RubyGems
  # belongs to an unrelated project. The require path and the `Predicate`
  # constant are unchanged; lib/predicate-rb.rb bridges Bundler.require.
  spec.name          = 'predicate-rb'
  spec.version       = Predicate::VERSION
  spec.authors       = ['Nauman Tariq']
  spec.email         = ['hello@nauman.one']

  spec.summary       = 'Boolean predicate DSL with caching for Ruby/Rails'
  spec.description   = <<~DESC
    A lightweight library for defining and evaluating boolean predicates with
    automatic caching, combinators, and optional Rails model integration.

    Features:
    - Pure boolean predicates with meta-programming DSL
    - Automatic memoization and caching with SHA256-based keys
    - Logical combinators (AND, OR, NOT, conditional)
    - Section-based predicate grouping
    - Rails auto-detection and model integration
    - Performance monitoring and statistics
    - TTL cache expiration
    - Thread-safe operations
  DESC

  spec.homepage      = 'https://github.com/StockLive-Group/predicate'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  # IMPORTANT: an explicit allowlist, never `git ls-files` and never Dir["**/*"].
  # This is a shipping control, not a packaging detail — it is what keeps
  # everything outside these paths out of the published gem. Do not "tidy" it.
  spec.files = Dir[
    'lib/**/*.rb',
    'README.md',
    'EXAMPLES.md',
    'LICENSE.txt',
    'CHANGELOG.md'
  ]

  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'json'

  # Metadata
  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/StockLive-Group/predicate',
    'changelog_uri' => 'https://github.com/StockLive-Group/predicate/blob/main/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/StockLive-Group/predicate/issues',
    'documentation_uri' => 'https://github.com/StockLive-Group/predicate/blob/main/README.md'
  }
end
