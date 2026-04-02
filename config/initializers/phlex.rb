# frozen_string_literal: true

module Views
end

# Views and Components namespaces bootstrapped together in this initializer
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
