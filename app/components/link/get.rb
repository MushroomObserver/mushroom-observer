# frozen_string_literal: true

# GET link — emits `<a>` with CRUD path-building and optional btn styling.
# Source of truth for model-targeted and path-targeted navigational links.
# `Components::Button::Get` and its subclasses (Edit, New, Download)
# delegate here with `button: nil`, producing `btn btn-default`.
#
# @example plain link (no button styling)
#   render(Components::Link::Get.new(
#     name: @herbarium.name, target: @herbarium
#   ))
#
# @example outlined button
#   render(Components::Link::Get.new(
#     name: :edit.ti, target: @herbarium, action: :edit,
#     icon: :edit, button: :outline
#   ))
#
# @example btn-link variant (underlined, no btn frame)
#   render(Components::Link::Get.new(
#     name: user.login, target: user_path(user.id), button: :link
#   ))
class Components::Link::Get < Components::Link
  include Components::CRUDPathBuilding

  def initialize(name:, target:, button: nil, new_tab: false, **opts)
    @name    = name
    @target  = target
    @method  = :get
    @new_tab = new_tab
    opts.delete(:confirm)
    @action  = opts.delete(:action)
    @back    = opts.delete(:back)
    opts.delete(:params)
    @size = opts.delete(:size)
    @icon = opts.delete(:icon)
    @icon_class = opts.delete(:icon_class)
    @icon_title = opts.delete(:icon_title)
    @label = opts.delete(:label)
    @html_attrs = opts
    validate_no_btn_classes!(@html_attrs[:class])
    super(button: button)
  end

  def view_template(&block)
    link_to(path, link_html_options) do
      block ? yield : button_content
    end
  end

  private

  def merged_class
    class_names(identifier, btn_styling, size_class(@size), @html_attrs[:class])
  end

  def link_html_options
    base = { class: merged_class }
    base.merge!(tooltip_data) if @icon
    base = base.deep_merge(@html_attrs.except(:class))
    if @new_tab
      base[:target] = "_blank"
      base[:rel] = "noopener noreferrer"
    end
    base
  end

  def tooltip_data
    { title: @name,
      data: { trigger: "tooltip", placement: "top", title: @name } }
  end
end
