# frozen_string_literal: true

# Action-nav for the "Add Members" project page. A one-tab
# Collection containing just a `Tab::Object::Return` link back to
# the project — the page itself doesn't need an index link because
# the project page is its parent.
class Tab::Project::Members::FormNew < Tab::Collection
  def initialize(project:)
    super()
    @project = project
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @project)]
  end
end
