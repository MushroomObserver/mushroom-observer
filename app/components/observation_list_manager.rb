# frozen_string_literal: true

# Two headed `Components::ListGroup` sections -- items an Observation
# belongs to, and items it doesn't -- shared by
# `Observations::Projects::Edit` and `Observations::SpeciesLists::Edit`.
# Row content is caller-supplied: the block receives `|item, remove,
# add|` for each row and renders whatever row component that caller
# uses (`Projects::ListItem`, `SpeciesLists::Listing`).
#
# @example
#   render(Components::ObservationListManager.new(
#     belongs_to_heading: :project_manage_belongs_to.l,
#     belongs_to_items: @obs_projects,
#     not_contains_heading: :project_manage_doesnt_contain.l,
#     not_contains_items: @other_projects
#   )) do |project, remove, add|
#     render(Views::Controllers::Projects::ListItem.new(
#       project: project, observation: @observation,
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

    h5(class: "mt-3 pl-3") { trusted_html(append_colon(heading)) }
    ListGroup do |list|
      items.each do |item|
        list.item(
          class: "d-flex justify-content-between align-items-start"
        ) do
          @row_block.call(item, remove, add)
        end
      end
    end
  end
end
