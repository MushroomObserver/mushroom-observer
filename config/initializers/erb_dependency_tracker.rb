# frozen_string_literal: true

# Teach ActionView's ERB dependency tracker to skip constant-style
# render arguments — i.e. `render(Components::Foo.new(...))` or
# `render(Views::Bar.new(...))`. Those are Phlex class references,
# not Rails partial paths.
#
# Why this matters
# ----------------
# ERBTracker's `RENDER_ARGUMENTS` regex can't see `::` as a delimiter,
# so for `render(Components::MatrixTable.new(...))` it captures only
# the first segment `Components` as the "dependency name". That then
# passes through `add_dynamic_dependency`, which appends
# `"#{dep.pluralize}/#{dep.singularize}"` — producing the bogus
# `"Components/Component"` partial path. The Digestor then tries to
# find a template for that name, fails, and logs:
#
#     ERROR -- :   Couldn't find template for digesting: Components/Component
#
# Same story for `Views::...` → `"Views/View"`. Every ERB partial that
# renders a Phlex class produces one of these benign-but-noisy log
# lines per test run.
#
# By Rails convention, dynamic render dependencies are instance- or
# local-variable names (lowercase), e.g. `render @post`, `render
# product`. A capitalized leading character is always a constant
# reference, which by definition isn't a partial path — so dropping
# them costs nothing and silences the noise at its source.
require "action_view/dependency_tracker"

ActionView::DependencyTracker::ERBTracker.prepend(
  Module.new do
    private

    def add_dynamic_dependency(dependencies, dependency)
      return if dependency&.match?(/\A[[:upper:]]/)

      super
    end
  end
)
