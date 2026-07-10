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
#
# @example A collapsible `<tbody>` instead of a `<div>`
#   render(Components::CollapseDiv.new(id: "target_subs_1", element: :tbody)) do
#     render_sub_rows
#   end
#
# @example Class-only, for callers that can't render the component
#   directly (e.g. inside Components::Table's `vanish`-based body
#   builder -- see Components::Table#body, and
#   projects/locations/tables.rb for a real caller)
#   tab.body(id: collapse_id,
#            class: Components::CollapseDiv.collapse_classes) do
#     render_sub_rows
#   end
class Components::CollapseDiv < Components::Base
  # `module_function`-style dual access, matching
  # `Components::Button::Styling`'s `btn_class`/`size_class`: callable
  # as `Components::CollapseDiv.collapse_classes(...)` for callers that
  # only need the class string (e.g. builder/registration code that
  # runs before the component itself could render), and as a private
  # instance method for `view_template` below.
  def self.collapse_classes(expanded: nil, panel: false, html_class: nil)
    [
      "collapse",
      ("in" if expanded), # Bootstrap 4: change "in" → "show"
      ("panel-collapse" if panel),
      html_class
    ].compact_blank.join(" ")
  end

  prop :id, _Nilable(String), default: nil
  prop :expanded, _Nilable(_Boolean), default: nil
  prop :panel, _Boolean, default: false
  prop :html_class, _Nilable(String), default: nil
  prop :attributes, _Hash(Symbol, _Any), default: -> { {} }
  prop :element, Symbol, default: :div

  def view_template(&block)
    send(@element,
         id: @id,
         class: collapse_classes,
         **@attributes.except(:class, :id),
         &block)
  end

  private

  def collapse_classes
    self.class.collapse_classes(expanded: @expanded, panel: @panel,
                                html_class: @html_class)
  end
end
