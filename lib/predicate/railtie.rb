# frozen_string_literal: true

module Predicate
  class Railtie < Rails::Railtie
    # Add app/predicates to autoload paths before configuration is finalized
    config.before_configuration do |app|
      predicates_path = Rails.root.join('app', 'predicates')
      app.config.autoload_paths << predicates_path if Dir.exist?(predicates_path)
    end

    config.to_prepare do
      # Clear the registry in development to allow code reloading
      Predicate.clear_registry! if Rails.env.development?
    end
  end
end
