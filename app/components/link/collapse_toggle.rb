# frozen_string_literal: true

# Bootstrap 3 collapse-trigger `<a>`. Renders an `href="#target_id"`
# link with `data-toggle="collapse"` and the matching ARIA attrs.
# Pass `collapsed: true` to add the `.collapsed` class (Bootstrap uses
# this to flip chevron icons via CSS when the pane is hidden).
#
# @example info-icon toggle (default open)
#   render(Components::Link::CollapseToggle.new(
#     target_id: "help_field_x", class: "info-collapse-trigger"
#   )) { render(Components::Icon.new(type: :question)) }
#
# @example chevron toggle (starts closed)
#   render(Components::Link::CollapseToggle.new(
#     target_id: "sub_rows_42", class: "panel-collapse-trigger",
#     collapsed: true
#   )) { render(Components::Icon.new(type: :chevron_down)) }
class Components::Link::CollapseToggle < Components::Link
  def initialize(target_id:, collapsed: false, **opts)
    @target_id = target_id
    @collapsed  = collapsed
    @html_class = opts.delete(:class)
    @extra_data = opts.delete(:data) || {}
    @html_attrs = opts
    super(button: nil)
  end

  def view_template(&block)
    a(
      href: "##{@target_id}",
      role: "button",
      class: class_names(@html_class, { "collapsed" => @collapsed }),
      data: { toggle: "collapse", **@extra_data },
      aria: { expanded: @collapsed ? "false" : "true", controls: @target_id },
      **@html_attrs, &block
    )
  end
end
