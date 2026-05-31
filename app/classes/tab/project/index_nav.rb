# frozen_string_literal: true

# Action-nav collection for the project index page — the "Add
# Project" link.
class Tab::Project::IndexNav < Tab::Collection
  private

  def tabs
    [Tab::Project::New.new]
  end
end
