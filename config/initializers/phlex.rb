# frozen_string_literal: true

# Views and Components namespaces bootstrapped together in this initializer.
# Both extend Phlex::Kit so callers can render via `render Views::Foo` and
# `render Components::Bar` shorthand (no `.new(...)`) inside a Phlex render
# context.
module Views
  extend Phlex::Kit
end

module Components # rubocop:disable Style/OneClassPerFile
  extend Phlex::Kit
end

# Register app/views and app/components with Zeitwerk under their
# respective namespaces. These push_dir calls run during
# load_config_initializers, which executes before setup_main_autoloader
# calls autoloader.setup — so the namespace mappings are in place when
# Zeitwerk walks the directories.
Rails.autoloaders.main.push_dir(
  Rails.root.join("app/views"), namespace: Views
)

Rails.autoloaders.main.push_dir(
  Rails.root.join("app/components"), namespace: Components
)
