# frozen_string_literal: true

# Grid box title component.
#
# Renders the title span for a grid box item. The title styling varies
# based on the object type - observations and names get regular weight
# (their text is already textile-bold/italic), while other types get
# bold weight. Pass `bold:` explicitly to override that type-based
# default -- e.g. an image box, whose title text comes from whichever
# subjects it's attached to (an already-bold observation name, or a
# plain glossary_term/user name) and so needs a per-image decision,
# not a per-type one.
#
# @example With observation
#   render Components::Grid::Box::Title.new(
#     id: obs.id,
#     name: obs.format_name,
#     type: :observation
#   )
#
# @example With user
#   render Components::Grid::Box::Title.new(
#     id: user.id,
#     name: user.unique_text_name,
#     type: :user
#   )
#
# @example With an explicit bold override
#   render Components::Grid::Box::Title.new(
#     id: image.id,
#     name: image.format_name,
#     type: :image,
#     bold: image.observations.empty?
#   )
class Components::Grid::Box::Title < Components::Base
  prop :id, Integer
  prop :name, String
  prop :type, Symbol
  prop :bold, _Nilable(_Boolean), default: nil

  def view_template
    span(
      class: class_names("log-name", title_weight),
      id: "box_title_#{@id}"
    ) { @name }
  end

  private

  def title_weight
    "font-weight-bold" if bold?
  end

  def bold?
    return @bold unless @bold.nil?

    [:observation, :name].exclude?(@type)
  end
end
