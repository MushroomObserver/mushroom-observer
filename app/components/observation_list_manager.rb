# frozen_string_literal: true

# Two headed sections -- items an Observation belongs to, and items it
# doesn't -- shared by `Observations::Projects::Edit` and
# `Observations::SpeciesLists::Edit`. Row/table content is
# caller-supplied: the block receives `|items, heading, remove, add|`
# once per non-empty section and renders whatever table component
# that caller uses (`Projects::ProjectTable`,
# `SpeciesLists::SpeciesListTable`) -- the heading becomes that
# table's first column header rather than a separate element.
#
# @example
#   render(Components::ObservationListManager.new(
#     belongs_to_heading: :project_manage_belongs_to.l,
#     belongs_to_items: @obs_projects,
#     not_contains_heading: :project_manage_doesnt_contain.l,
#     not_contains_items: @other_projects
#   )) do |projects, heading, remove, add|
#     render(Views::Controllers::Projects::ProjectTable.new(
#       projects, heading: heading, observation: @observation,
#       remove: remove, add: add
#     ))
#   end
class Components::ObservationListManager < Components::Base
  prop :belongs_to_heading, String
  prop :belongs_to_items, _Interface(:each)
  prop :not_contains_heading, String
  prop :not_contains_items, _Interface(:each)

  def view_template(&block)
    @row_block = block
    render_section(heading: @belongs_to_heading,
                   items: @belongs_to_items, remove: true)
    render_section(heading: @not_contains_heading,
                   items: @not_contains_items, add: true)
  end

  private

  def render_section(heading:, items:, remove: false, add: false)
    return if items.empty?

    @row_block.call(items, heading, remove, add)
  end
end
