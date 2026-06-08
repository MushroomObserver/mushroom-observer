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

# Auto-include every top-level `Tabs::*Helper` module into
# `Views::Base` so they're callable from any Phlex view without
# `helpers.*` or per-class `register_value_helper`. Guards
# `defined?(Tabs)` because the `tabs/` helpers directory is
# currently empty — there are no top-level Tabs helpers right
# now, so referencing the constant unguarded would NameError.
#
# Nested helpers under `Tabs::Sidebar::*`, `Tabs::Locations::*`,
# `Tabs::Names::*` are NOT included here — they stay scoped to
# their specific callers (e.g. `Views::Layouts::ApplicationSidebar`
# includes `Tabs::Sidebar::AdminHelper` etc. explicitly).
Rails.application.config.to_prepare do
  next unless defined?(Tabs)

  Tabs.constants.each do |name|
    next unless name.to_s.end_with?("Helper")

    mod = Tabs.const_get(name)
    Views::Base.include(mod) if mod.is_a?(Module)
  end
end
