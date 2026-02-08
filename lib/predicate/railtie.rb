# frozen_string_literal: true

module Predicate
  class Railtie < Rails::Railtie
    initializer 'predicate.configure_autoloading' do
      predicates_path = Rails.root.join('app', 'predicates')
      if Dir.exist?(predicates_path)
        # Predicate files register entries via Predicate.define — they don't
        # define Ruby constants. Tell Zeitwerk to skip them.
        # Loading is handled by ModelIntegration.load_predicates! via Kernel#load.
        Rails.autoloaders.main.ignore(predicates_path)
      end
    end

    config.to_prepare do
      Predicate.clear_registry! if Rails.env.development?
    end
  end
end
