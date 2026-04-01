# frozen_string_literal: true

module Views
end

# Views and Components namespaces bootstrapped together in this initializer
module Components # rubocop:disable Style/OneClassPerFile
  extend Phlex::Kit
end

# The Views push_dir is in config/application.rb so it runs before
# Zeitwerk setup (push_dir after setup is a no-op).
# Components is already in Rails' default autoload paths (app/*),
# so push_dir here works fine for adding the namespace.
Rails.autoloaders.main.push_dir(
  Rails.root.join("app/components"), namespace: Components
)
