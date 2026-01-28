# frozen_string_literal: true

require_relative 'lib/predicate/version'

Gem::Specification.new do |spec|
  spec.name          = 'predicate'
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

  # Specify which files should be added to the gem when it is released
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
    'documentation_uri' => 'https://github.com/StockLive-Group/predicate/blob/main/README.md',
    'rubygems_mfa_required' => 'true'
  }
end
