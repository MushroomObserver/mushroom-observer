# frozen_string_literal: true

# GET link — emits `<a>` with CRUD path-building and optional btn styling.
# Source of truth for model-targeted and path-targeted navigational links.
# `Components::Button::Get` and its subclasses (Edit, New, Download)
# delegate here with `button: :default`, producing `btn btn-default`.
#
# @example plain link (no button styling)
#   render(Components::Link::Get.new(
#     name: @herbarium.name, target: @herbarium
#   ))
#
# @example outlined button
#   render(Components::Link::Get.new(
#     name: :EDIT.l, target: @herbarium, action: :edit,
#     icon: :edit, button: :outline
#   ))
#
# @example btn-link variant (underlined, no btn frame)
#   render(Components::Link::Get.new(
#     name: user.login, target: user_path(user.id), button: :btn_link
#   ))
class Components::Link::Get < Components::Link
  include Components::CRUDPathBuilding

  def initialize(name:, target:, button: nil, new_tab: false, **opts)
    @name    = name
    @target  = target
    @method  = :get
    @new_tab = new_tab
    @confirm = opts.delete(:confirm)
    @action  = opts.delete(:action)
    @back    = opts.delete(:back)
    @params  = opts.delete(:params)
    @size    = opts.delete(:size)
    @icon    = opts.delete(:icon)
    @icon_class = opts.delete(:icon_class)
    @html_attrs = opts
    validate_no_btn_classes!(@html_attrs[:class])
    super(button: button)
  end

  def view_template
    link_to(path, link_html_options) { button_content }
  end

  private

  def merged_class
    class_names(identifier, btn_styling, size_class(@size), @html_attrs[:class])
  end

  def link_html_options
    base = { class: merged_class }
    base.merge!(tooltip_data) if @icon
    if @new_tab
      base[:target] = "_blank"
      base[:rel] = "noopener noreferrer"
    end
    base.deep_merge(@html_attrs.except(:class))
  end

  def tooltip_data
    { title: @name,
      data: { toggle: "tooltip", placement: "top", title: @name } }
  end
end
