# frozen_string_literal: true

# Views and Components namespaces bootstrapped together in this initializer.
#
# Only `Components` extends `Phlex::Kit` — deliberately not `Views`.
# `Phlex::Kit` generates a bare, callable method for every class
# directly under the extending namespace (`Components::Icon` →
# `Icon(...)`), replacing BOTH the `render(...)` call AND the `.new(...)`
# call in one shot — a caller writes `Icon(type: :edit)`, never
# `render(Components::Icon.new(type: :edit))`. `Views` classes never
# benefit from this: every real view lives 2+ levels deep
# (`Views::Controllers::<Controller>::<Action>`, see the "Action-
# template + sub-view organization" convention in
# `.claude/rules/phlex_reference.md`), and Kit sugar only fires for classes
# exactly one level under the extending namespace. Extending `Views`
# would just add a dead `extend` with no real caller ever able to use
# it — the only classes directly under `Views` are abstract bases
# (`Views::Base`, `Views::FullPageBase`) that are never rendered
# directly.
module Views; end

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
