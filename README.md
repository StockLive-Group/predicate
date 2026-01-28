# Predicate Library

A lightweight, high-performance predicate evaluation library for Ruby/Rails applications with automatic caching, TTL support, and thread-safe operations.

## 💡 Why This Exists

Rails apps tend to repeat the same decision logic in three places:

- Controllers (`before_action` filters, multi-step wizards)
- Models/helpers (validations, scopes, callbacks)
- Front-end code (React/Vue components mirroring server rules)

We built Predicate to centralize those boolean rules. Define the logic once,
share it between controllers/models/tests, and expose the same truth to the
front-end (JSON endpoints or server-rendered flags). The goals:

1. **Reduce duplication** – No more copy/pasted "can_publish?" guards.
2. **Keep JS thin** – Let Rails compute the booleans; the UI just renders them.
3. **Improve confidence** – Predicates are pure functions with deterministic
   caching, so tests can focus on business intent rather than wiring.
4. **Reusable across projects** – As a standalone gem, predicate logic can be
   shared across multiple services and applications.

## 🎯 Features

- **Pure Boolean Logic** - All predicates return `true` or `false` (never `nil`)
- **Meta-Programming DSL** - English-like syntax with `method_missing` magic
- **Collision-Free Caching** - SHA256-based deterministic cache keys
- **TTL Cache Expiration** - Optional time-based cache invalidation
- **Thread-Safe Operations** - Mutex-protected cache for Puma/Sidekiq
- **Rails Integration** - Seamless ActiveRecord model integration
- **Validation Helpers** - Auto-generate predicates from Rails validations
- **Boolean Combinators** - AND, OR, NOT, XOR conditional logic
- **Section Grouping** - Organize related predicates
- **Performance Monitoring** - Built-in statistics and tracking
- **LRU Cache Eviction** - Smart memory management (1000 entry limit)

## 📦 Installation

### As a Gem

Add to your Gemfile:

```ruby
# From GitHub
gem 'predicate', git: 'git@github.com:StockLive-Group/predicate.git', branch: 'main'

# Or from a local path during development
# gem 'predicate', path: '../75-predicate'
```

Then run:

```bash
bundle install
```

The gem will automatically integrate with Rails via Railtie if Rails is detected.

## 🚀 Quick Start

### 1. Define Predicates

```ruby
Predicate.define(:assessment) do
  has_media { |s| present?(s[:media_attachment_ids]) }
  has_title { |s| present?(s[:title]) }
  wizard_complete { |s| has_media(s) && has_title(s) }
end
```

### 2. Use in Models

```ruby
class Assessment < ApplicationRecord
  include Predicate::ModelIntegration
end

# Automatic methods on model instances:
assessment = Assessment.first
assessment.has_media?        # => true
assessment.wizard_complete?  # => false
```

### 3. Call Directly

```ruby
predicates = Predicate.for(:assessment)
state = { media_attachment_ids: [1, 2], title: 'Test' }

predicates.call(:has_media, state)        # => true
predicates.call(:wizard_complete, state)  # => true
```

## 🧩 Full Integration Workflow

To run Predicate across controllers, views, jobs, and front-end consumers:

1. **Create a predicate directory**

   ```bash
   mkdir -p app/predicates
   ```

2. **Generate a predicate skeleton** (from `rails console` or `rails runner`):

   ```ruby
   Predicate::ModelIntegration::PredicateFileGenerator.generate_for_model(
     Assessment,
     Rails.root.join('app/predicates/assessment_predicate.rb')
   )
   ```

3. **Include the integration module** in your model:

   ```ruby
   class Assessment < ApplicationRecord
     include Predicate::ModelIntegration
   end
   ```

4. **Define predicates** inside the generated file.

5. **Expose results everywhere**: `assessment.has_media?` in controllers/views,
   JSON endpoints for React/Vue, and direct `Predicate.for(:assessment)` calls in
   jobs or services.

## 🧪 End-to-End Example

### Definition (`app/predicates/assessment_predicate.rb`)

```ruby
Predicate.define(:assessment, cache_ttl: 5.minutes, thread_safe: true) do
  has_media { |s| s[:media_attachment_ids].any? }
  has_title { |s| s[:title].present? }

  wizard_complete do |state|
    has_media(state) && has_title(state)
  end
end
```

### Usage & Results

```ruby
assessment = Assessment.find(42)

assessment.has_media?        # => true
assessment.has_title?        # => false
assessment.wizard_complete?  # => false

state = assessment.attributes.symbolize_keys
Predicate.for(:assessment).call(:wizard_complete, state)
# => false
```

> Need more scenarios? `EXAMPLES.md` contains 30+ real-world definitions with
> matching usage/output snippets.


## 📖 Complete Usage Guide

### Basic Predicates

```ruby
Predicate.define(:product) do
  # Simple presence checks
  has_name { |s| present?(s[:name]) }
  has_price { |s| present?(s[:price]) }

  # Numeric comparisons
  in_stock { |s| s[:quantity] > 0 }
  on_sale { |s| s[:discount] > 0 }

  # Combining predicates
  ready_to_sell { |s| has_name(s) && has_price(s) && in_stock(s) }
end
```

### Section-Based Organization

```ruby
Predicate.define(:sale) do
  section :validation do
    has_customer { |s| present?(s[:customer_id]) }
    has_items { |s| s[:line_items]&.any? }
    ready_to_invoice { |s| has_customer(s) && has_items(s) }
  end

  section :permissions do
    can_edit { |s| s[:user_role] == 'admin' }
    can_delete { |s| can_edit(s) && s[:status] == 'draft' }
  end
end

# Call section predicates
predicates = Predicate.for(:sale)
predicates.call_section(:validation, :ready_to_invoice, sale_state)
# => true/false
```

### TTL (Time-To-Live) Cache Expiration

```ruby
# Cache results for 5 minutes
Predicate.define(:expensive_check, cache_ttl: 5.minutes) do
  api_result { |s| expensive_api_call(s[:id]) }
  complex_calculation { |s| heavy_computation(s[:data]) }
end

# First call: executes and caches
# Within 5 minutes: returns cached result
# After 5 minutes: cache expires, re-executes
```

### Thread-Safe Mode (for Puma/Sidekiq)

```ruby
# Enable thread-safe cache operations
Predicate.define(:concurrent_checks, thread_safe: true) do
  check_status { |s| s[:status] == 'active' }
  check_inventory { |s| s[:quantity] > 0 }
end

# Safe for concurrent access from multiple threads
# Uses Mutex to protect cache operations
```

### Validation Helpers (Rails Integration)

```ruby
Predicate.define(:user) do
  # Auto-generates predicates from validations
  validates_presence_of(:name, :email)
  validates_format_of(:email, with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  validates_numericality_of(:age, greater_than: 0, less_than: 150)
  validates_length_of(:password, minimum: 8)
end

# Generates predicates:
# - has_name
# - has_email
# - required_fields
# - valid_email_format
# - valid_age
# - valid_password_length

predicates = Predicate.for(:user)
predicates.call(:has_name, { name: 'John' })  # => true
predicates.call(:valid_email_format, { email: 'invalid' })  # => false
```

### English-Like Helpers

The library provides 27 English-like helper methods for common checks:

```ruby
Predicate.define(:user) do
  # Presence/Blank checks
  has_email { |s| present?(s[:email]) }
  no_email { |s| blank?(s[:email]) }

  # Boolean helpers
  is_enabled { |s| truthy?(s[:enabled]) }
  is_disabled { |s| falsy?(s[:enabled]) }
  is_inverted { |s| not?(s[:active]) }

  # Type checks
  is_string { |s| is_type?(s[:value], String) }
  is_array { |s| is_type?(s[:value], Array) }
  is_one_of_types { |s| is_one_of?(s[:value], [String, Integer]) }

  # Collection checks
  has_tags { |s| has_elements?(s[:tags]) }
  has_metadata { |s| has_keys?(s[:metadata]) }

  # Value checks
  is_valid_status { |s| is_one_of_values?(s[:status], %w[active pending]) }
  is_invalid_status { |s| is_not_one_of_values?(s[:status], %w[banned deleted]) }

  # Comparison helpers
  age_valid { |s|
    greater_than?(s[:age], 0) && less_than?(s[:age], 150)
  }
  age_range { |s| in_range?(s[:age], 18..100) }

  # String helpers
  name_length_valid { |s|
    min_length?(s[:name], 3) && max_length?(s[:name], 50)
  }
  email_valid { |s| matches?(s[:email], /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }

  # Math helpers
  is_positive { |s| positive?(s[:amount]) }
  is_negative { |s| negative?(s[:balance]) }
  is_zero { |s| zero?(s[:balance]) }

  # Equality checks
  account_active { |s| equal_to?(s[:status], 'active') }
  account_inactive { |s| not_equal_to?(s[:status], 'active') }
end
```

**Complete Helper List:**
- **Presence**: `present?(value)`, `blank?(value)`
- **Boolean**: `not?(value)`, `truthy?(value)`, `falsy?(value)`
- **Math**: `positive?(value)`, `negative?(value)`, `zero?(value)`
- **Collections**: `has_elements?(value)`, `has_keys?(value)`
- **String Length**: `min_length?(value, min)`, `max_length?(value, max)`
- **Value Comparison**: `min_value?(value, min)`, `max_value?(value, max)`
- **Range**: `in_range?(value, range)`, `matches?(value, pattern)`
- **Type Checks**: `is_type?(value, type)`, `is_one_of?(value, types)`
- **Value Membership**: `is_one_of_values?(value, values)`, `is_not_one_of_values?(value, values)`
- **Equality**: `equal_to?(value, other)`, `not_equal_to?(value, other)`
- **Numeric**: `greater_than?(value, other)`, `less_than?(value, other)`, `greater_than_or_equal_to?(value, other)`, `less_than_or_equal_to?(value, other)`

### Boolean Combinators

```ruby
Predicate.define(:complex) do
  cond_a { |s| s[:a] == 1 }
  cond_b { |s| s[:b] == 2 }
  cond_c { |s| s[:c] == 3 }

  # Built-in combinators
  all_true { |s| and_all(cond_a(s), cond_b(s), cond_c(s)) }
  any_true { |s| or_any(cond_a(s), cond_b(s), cond_c(s)) }
  not_a { |s| not?(cond_a(s)) }
  xor_check { |s| xor(cond_a(s), cond_b(s)) }
end
```

## 🎮 Rails Console Examples

### Basic Usage

```ruby
# Start Rails console
rails c

# Define predicates
Predicate.define(:product) do
  in_stock { |s| s[:quantity] > 0 }
  on_sale { |s| s[:discount] > 0 }
  featured { |s| in_stock(s) && on_sale(s) }
end

# Test predicates
predicates = Predicate.for(:product)
predicates.call(:featured, { quantity: 10, discount: 15 })
# => true

# Check performance stats
predicates.performance_stats
# => {:featured=>{:calls=>1, :total_time=>0.0001, :average_time=>0.0001, :min_time=>0.0001, :max_time=>0.0001}}

# Check cache stats
predicates.cache_stats
# => {:cached_results=>1, :predicates=>3, :sections=>0, :cache_hits=>0, :cache_misses=>1, :cache_hit_ratio=>0.0}
```

### With Rails Models

```ruby
# In app/models/assessment.rb
class Assessment < ApplicationRecord
  include Predicate::ModelIntegration
end

# In app/predicates/assessment_predicates.rb
Predicate.define(:assessment) do
  has_media { |s| present?(s[:media_attachment_ids]) }
  has_title { |s| present?(s[:title]) && s[:title].length >= 3 }
  has_description { |s| present?(s[:description]) && s[:description].length >= 10 }

  content_complete { |s| has_title(s) && has_description(s) }
  wizard_complete { |s| has_media(s) && content_complete(s) }
end

# In Rails console
rails c

assessment = Assessment.first
assessment.has_media?          # => true
assessment.wizard_complete?    # => false

# Force reload predicates (during development)
Assessment.load_predicates!(force_reload: true)
```

### Testing Cache Behavior

```ruby
rails c

Predicate.define(:test, cache_ttl: 10.seconds) do
  timestamp { |s| Time.now.to_f }
end

predicates = Predicate.for(:test)

# First call
result1 = predicates.call(:timestamp, {})
# => 1699876543.123

# Immediate second call (cached)
result2 = predicates.call(:timestamp, {})
# => 1699876543.123 (same as first!)

# Wait 11 seconds...
sleep 11

# After TTL expiry (new value)
result3 = predicates.call(:timestamp, {})
# => 1699876554.789 (different!)

# Check cache stats
predicates.cache_stats
# => {:cache_hits=>1, :cache_misses=>2, :cache_hit_ratio=>0.333}
```

### Thread-Safety Testing

```ruby
rails c

Predicate.define(:counter, thread_safe: true) do
  count do |s|
    s[:value] ||= 0
    s[:value] + 1
  end
end

predicates = Predicate.for(:counter)

# Spawn multiple threads
threads = 10.times.map do |i|
  Thread.new do
    predicates.call(:count, { id: i, value: i * 10 })
  end
end

threads.each(&:join)

# Check cache (should have 10 entries, no corruption)
predicates.cache_stats
# => {:cached_results=>10, :cache_hits=>0, :cache_misses=>10}
```

## 🧪 Testing

### Run All Tests

```bash
cd lib/predicate
ruby test_runner.rb
# or
rake test
```

### Run Specific Tests

```bash
ruby -Ilib -Itest test/core_test.rb
ruby -Ilib -Itest test/ttl_test.rb
ruby -Ilib -Itest test/thread_safety_test.rb
```

### Test Results

```
✅ ALL TESTS PASS: 183 runs, 508 assertions, 0 failures, 0 errors

Test Coverage:
✅ Core Tests               - Core engine functionality
✅ DSL Tests                - Builder and DSL features
✅ Combinators Tests        - Boolean logic operators
✅ Cache Collision Tests    - SHA256 collision-free keys
✅ Model Integration Tests  - Rails ActiveRecord integration
✅ TTL Tests                - Time-based cache expiration
✅ Thread-Safety Tests      - Concurrent access protection
✅ Validation Helper Tests  - Rails validation integration
✅ Force Reload Tests       - Development workflow
✅ Performance Tests        - Metrics tracking
✅ Section Tests            - Section caching guardrails
```

## 📊 Performance

### Cache Characteristics

- **Cache Size**: 1000 entries (default)
- **Eviction Strategy**: LRU (removes oldest 25% when full)
- **TTL Cleanup**: Periodic cleanup every 100 writes
- **Cache Keys**: SHA256-based (first 16 chars)
- **Hit Rate**: Typically 70-90% for repeated evaluations

### Performance Stats

```ruby
predicates = Predicate.for(:assessment)
stats = predicates.performance_stats

# Returns:
{
  has_media: {
    calls: 150,
    total_time: 0.045,
    average_time: 0.0003,
    min_time: 0.0001,
    max_time: 0.002
  }
}
```

### Complexity

- Cache lookup: O(1) with SHA256 hash
- Cache insertion: O(1) average
- Cache eviction: O(n/4) when limit reached
- TTL cleanup: O(n) every 100 writes
- Thread-safe overhead: ~10-20% with Mutex

## 🏗️ Architecture

```
Predicate Library
├── Predicate::Core           # Evaluation engine
│   ├── Caching (SHA256 keys, LRU eviction)
│   ├── TTL expiration
│   ├── Thread-safety (Mutex)
│   ├── Performance tracking
│   └── English helpers
├── Predicate::DSL            # Builder with method_missing
│   ├── Predicate definitions
│   ├── Section grouping
│   └── Validation helpers
├── Predicate::Combinators    # Boolean logic operators
├── Predicate::Registry       # Singleton storage
└── Predicate::ModelIntegration  # Rails ActiveRecord integration
```

## 📁 Project Structure

```
lib/predicate/
├── lib/
│   ├── predicate.rb                    # Main entry point & Registry
│   └── predicate/
│       ├── core.rb                     # Evaluation engine
│       ├── dsl.rb                      # Meta-programming DSL
│       ├── combinators.rb              # Boolean operators
│       └── model_integration.rb        # Rails integration
├── test/                               # Test suite (14 files)
│   ├── core_test.rb
│   ├── ttl_test.rb
│   ├── thread_safety_test.rb
│   └── ... (11 more test files)
├── doc/                                # Generated RDoc (git-ignored)
├── README.md                           # This file
├── Rakefile                            # Test tasks
├── Gemfile                             # Dependencies
└── predicate.gemspec                   # Gem specification
```

## 📚 Documentation

### RDoc

Generate comprehensive API documentation:

```bash
cd lib/predicate
rdoc --output doc --main README.md --title "Predicate Library Documentation" lib/ README.md
open doc/index.html
```

Coverage: **84.62%** (121 out of 143 items documented)

### Guides

- **[EXAMPLES.md](EXAMPLES.md)** — Comprehensive examples with 30 scenarios covering all features and practical patterns
  - **Basic Features** (1-15): Predicates, sections, validation helpers, combinators, caching, threading
  - **Real-World Use Cases** (16-24): API validation, feature flags, webhooks, RBAC, workflows, batch processing
  - **Refactoring Patterns** (25-30): Controllers, helpers, views, policies, forms, background jobs
  - Before/after comparisons showing code reduction and performance improvements
  - Generic examples applicable to any Rails application

## 🎯 Use Cases

### 1. Multi-Step Form/Wizard Completion

```ruby
Predicate.define(:onboarding) do
  step1_complete { |user| present?(user[:email]) && present?(user[:name]) }
  step2_complete { |user| present?(user[:company]) }
  step3_complete { |user| user[:preferences]&.any? }

  can_proceed_to_step2 { |user| step1_complete(user) }
  can_proceed_to_step3 { |user| step1_complete(user) && step2_complete(user) }
  onboarding_complete { |user|
    step1_complete(user) && step2_complete(user) && step3_complete(user)
  }
end
```

### 2. Permission Checks

```ruby
Predicate.define(:document) do
  is_owner { |ctx| ctx[:document].user_id == ctx[:current_user].id }
  is_admin { |ctx| ctx[:current_user].role == 'admin' }
  is_public { |ctx| ctx[:document].visibility == 'public' }

  can_view { |ctx| is_public(ctx) || is_owner(ctx) || is_admin(ctx) }
  can_edit { |ctx| is_owner(ctx) || is_admin(ctx) }
  can_delete { |ctx| is_owner(ctx) }
end
```

### 3. Business Rule Validation

```ruby
Predicate.define(:order) do
  has_items { |order| order[:items]&.any? }
  has_shipping { |order| present?(order[:shipping_address]) }
  has_payment { |order| present?(order[:payment_method_id]) }
  above_minimum { |order| order[:total] >= 10.00 }

  can_checkout { |order|
    has_items(order) &&
    has_shipping(order) &&
    has_payment(order) &&
    above_minimum(order)
  }
end
```

### 4. Feature Flags

```ruby
Predicate.define(:features) do
  beta_user { |user| user[:beta_tester] == true }
  paid_plan { |user| user[:subscription_plan] != 'free' }

  show_advanced_features { |user| paid_plan(user) }
  show_beta_features { |user| beta_user(user) }
  show_export_button { |user| paid_plan(user) && user[:export_enabled] }
end
```

## ⚙️ Configuration

### Global Settings

```ruby
# Default cache size is 1000 entries
# TTL is optional (nil = no expiration)
# Thread-safety is opt-in (default: false)

# Per-entity configuration
Predicate.define(:fast_check, cache_ttl: 1.minute) { ... }
Predicate.define(:concurrent_check, thread_safe: true) { ... }
Predicate.define(:production, cache_ttl: 5.minutes, thread_safe: true) { ... }
```

### Cache Management

```ruby
# Clear cache for specific entity
predicates = Predicate.for(:assessment)
predicates.clear_cache!

# Clear all caches across all entities
Predicate.clear_cache!

# Clear registry (remove all predicates)
Predicate.clear_registry!
```

## 🛠️ Troubleshooting

### Cache Not Updating

```ruby
# Force reload predicates from file
Assessment.load_predicates!(force_reload: true)

# Or clear cache manually
Predicate.for(:assessment).clear_cache!
```

### Predicate Not Found

```ruby
# Check registered predicates
predicates = Predicate.for(:assessment)
predicates.predicate_names
# => [:has_title, :has_media, :wizard_complete]

# Check sections
predicates.section_names
# => [:validation, :permissions]
```

### Performance Issues

```ruby
# Check cache hit rate
stats = predicates.cache_stats
hit_rate = stats[:cache_hit_ratio]

# Low hit rate? Consider increasing cache size or enabling TTL

# Check slow predicates
perf = predicates.performance_stats
slow_predicates = perf.select { |_, s| s[:average_time] > 0.01 }
```

## 🤝 Contributing

For bugs or feature requests, contact the development team.

## 📄 License

Proprietary - StockLive Internal Use Only

## 👤 Authors

Nauman Tariq - Initial design and implementation

## 📌 Version

**1.0.0** - Initial Release (November 2025)
