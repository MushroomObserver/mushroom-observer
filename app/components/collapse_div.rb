# frozen_string_literal: true

# Renders a Bootstrap collapse target `<div>`.
#
# Centralises the one Bootstrap 3→4 migration risk: Bootstrap 3 uses the
# class `"in"` for the initially-open state; Bootstrap 4 uses `"show"`.
# Change the `expanded:` branch here when upgrading.
#
# @example Basic (initially closed)
#   render(Components::CollapseDiv.new(id: "my_section")) do
#     plain("Hidden content")
#   end
#
# @example Initially open
#   render(Components::CollapseDiv.new(id: "geo", expanded: true)) do
#     render_fields
#   end
#
# @example Inside a Panel (adds panel-collapse class)
#   render(Components::CollapseDiv.new(id: "obs_body", expanded: @expanded,
#                                      panel: true)) do
#     render_body
#   end
#
# @example With extra Stimulus data attrs
#   render(Components::CollapseDiv.new(
#            id: "obs_geo",
#            expanded: @observation.lat.present?,
#            attributes: { data: { form_exif_target: "collapseFields" } }
#          )) do
#     render_fields
#   end
class Components::CollapseDiv < Components::Base
  prop :id, _Nilable(String), default: nil
  prop :expanded, _Nilable(_Boolean), default: nil
  prop :panel, _Boolean, default: false
  prop :html_class, _Nilable(String), default: nil
  prop :attributes, _Hash(Symbol, _Any), default: -> { {} }

  def view_template(&block)
    div(id: @id,
        class: collapse_classes,
        **@attributes,
        &block)
  end

  private

  def collapse_classes
    class_names(
      "collapse",
      ("in" if @expanded), # Bootstrap 4: change "in" → "show"
      ("panel-collapse" if @panel),
      @html_class
    )
  end
end
