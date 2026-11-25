# frozen_string_literal: true

# Grid box title component. Renders the title span for a grid box
# item -- observations/names default to regular weight (already
# textile-bold/italic), other types default to bold. Pass `bold:`
# to override per instance -- e.g. an image box, whose title comes
# from whichever subject it's attached to, needs a per-image
# decision rather than the type-based default.
#
# @example
#   render Grid::Box::Title.new(id: image.id, name: image.format_name,
#                               type: :image, bold: false)
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
