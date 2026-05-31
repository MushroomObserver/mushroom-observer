# frozen_string_literal: true

# Action-nav collection for the project "new" form — just a
# cancel-to-index link. Trivial single-tab Collection, kept for
# parity with `add_context_nav` convention.
class Tab::Project::FormNew < Tab::Collection
  private

  def tabs
    [Tab::Project::Index.new]
  end
end
