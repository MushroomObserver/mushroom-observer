# frozen_string_literal: true

module Views
end

module Components
  extend Phlex::Kit
end

Rails.autoloaders.main.push_dir(
  Rails.root.join("app/views"), namespace: Views
)

Rails.autoloaders.main.push_dir(
  Rails.root.join("app/components"), namespace: Components
)

# Eagerly load all views to ensure nested modules are available
Rails.application.config.after_initialize do
  Rails.root.glob("app/views/**/*.rb").each do |file|
    require file
  end
end
