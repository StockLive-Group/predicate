# frozen_string_literal: true

module Predicate
  class Railtie < Rails::Railtie
    initializer 'predicate.configure_rails' do |app|
      # Add app/predicates to the autoload paths
      app.config.autoload_paths << Rails.root.join('app', 'predicates')
    end

    config.to_prepare do
      # Clear the registry in development to allow code reloading
      Predicate.clear_registry! if Rails.env.development?
    end
  end
end
