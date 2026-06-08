# frozen_string_literal: true

# Collection of the action-link tabs at the bottom of the Name
# classification panel. Composes:
#
#   - `Tab::Name::Subtaxa`               (always, when `@first_child`)
#   - `Tab::Name::RefreshClassification` (visibility-gated via `.for`)
#   - `Tab::Name::PropagateClassification` (visibility-gated, AND
#                                          requires `@first_child`)
#   - `Tab::Name::InheritClassification` (visibility-gated via `.for`)
#
# The 5th classification panel element — the approved-name + parents
# chain (`render_approved_name_and_parents`) — is multi-row content,
# not a single link, so it stays inline on the Phlex view.
#
# `Views::Controllers::Names::Show::ClassificationPanel` consumes
# via `each` — orchestration of "show subtaxa iff first_child",
# "show propagate iff first_child AND can_propagate? AND
# classification.present?", etc. lives here.
class Tab::Name::ClassificationLinks < Tab::Collection
  def initialize(name:, children_query:, first_child:, controller:)
    super()
    @name = name
    @children_query = children_query
    @first_child = first_child
    @controller = controller
  end

  private

  def tabs
    [
      subtaxa_tab,
      Tab::Name::RefreshClassification.for(name: @name),
      propagate_tab,
      Tab::Name::InheritClassification.for(name: @name)
    ].compact
  end

  def subtaxa_tab
    return nil unless @first_child

    Tab::Name::Subtaxa.new(
      name: @name, children_query: @children_query,
      controller: @controller
    )
  end

  # Propagate-classification has its own `.for(name:)` predicate
  # (`name.can_propagate? && name.classification.present?`), but it
  # ALSO requires `@first_child` to be present — the controller's
  # subtaxa check. Stack both guards here so the Tab itself stays
  # request-agnostic.
  def propagate_tab
    return nil unless @first_child

    Tab::Name::PropagateClassification.for(name: @name)
  end
end
