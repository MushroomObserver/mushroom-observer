# frozen_string_literal: true

# Matrix box title component.
#
# Renders the title span for a matrix box item. The title styling varies
# based on the object type - observations and names get regular weight,
# while other types get bold weight.
#
# @example With observation
#   render MatrixBoxTitle.new(
#     id: obs.id,
#     name: obs.format_name,
#     type: :observation
#   )
#
# @example With user
#   render MatrixBoxTitle.new(
#     id: user.id,
#     name: user.unique_text_name,
#     type: :user
#   )
class Components::Matrix::Box::Title < Components::Base
  prop :id, Integer
  prop :name, String
  prop :type, Symbol

  def view_template
    span(
      class: class_names("rss-name", title_weight),
      id: "box_title_#{@id}"
    ) { @name }
  end

  private

  def title_weight
    "font-weight-bold" unless [:observation, :name].include?(@type)
  end
end
