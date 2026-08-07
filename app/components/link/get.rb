# frozen_string_literal: true

# GET link — emits `<a>` with CRUD path-building and optional btn styling.
# Source of truth for model-targeted, path-targeted, and Tab-PORO-
# targeted navigational links. `Components::Button::Get` and its
# subclasses (Edit, New, Download) delegate here with `button: nil`,
# producing `btn btn-default`.
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
#
# @example from a Tab PORO (shortcut) -- title/path/html_options come
#   # from the tab; any of name:/target:/icon:/etc. passed alongside
#   # `tab:` override the tab's own value for that key.
#   render(Components::Link::Get.new(tab: Tab::Name::Edit.new(name: @name)))
#
# @example stateful icon+label swap (e.g. a subscribe toggle) -- pass
#   # active_icon:/active_content: together to additionally render a
#   # second icon/label pair; CSS shows/hides each pair based on an
#   # `.active`/`.collapsed` class toggled on the trigger by JS not
#   # yet written (see `_icons.scss`'s `.stateful-link` rule).
#   render(Components::Link::Get.new(
#     name: "Subscribe", target: subscribe_path, icon: :bullhorn,
#     active_icon: :check, active_content: "Subscribed"
#   ))
#
# @example destructive action -- renders `<form><button>` instead of
#   # `<a>`, with a Turbo confirm dialog before submitting.
#   render(Components::Link::Get.new(
#     name: :delete.ti, target: @obj, icon: :delete,
#     button_to: true, confirm: :are_you_sure.l
#   ))
class Components::Link::Get < Components::Link
  include Components::CRUDPathBuilding
  include Components::Link::TabTarget

  def initialize(name: nil, target: nil, button: nil, new_tab: false, **opts)
    tab = opts.delete(:tab)
    name, target, opts = resolve_tab_args(tab, name, target, opts)
    @name    = name
    @target  = target
    @method  = :get
    @new_tab = new_tab
    assign_icon_and_html_opts(opts)
    validate_no_btn_classes!(@html_attrs[:class])
    super(button: button)
  end

  def view_template(&block)
    tag_method = @button_to ? :button_to : :link_to
    send(tag_method, path, link_html_options) do
      block ? yield : button_content
    end
  end

  private

  def assign_icon_and_html_opts(opts)
    @confirm    = opts.delete(:confirm)
    @button_to  = opts.delete(:button_to)
    @action     = opts.delete(:action)
    @back       = opts.delete(:back)
    opts.delete(:params)
    @size = opts.delete(:size)
    @icon = opts.delete(:icon)
    @icon_class = opts.delete(:icon_class)
    @icon_title = opts.delete(:icon_title)
    @active_icon = opts.delete(:active_icon)
    @active_content = opts.delete(:active_content)
    @label = opts.delete(:label)
    @html_attrs = opts
  end

  def merged_class
    class_names(identifier, stateful_class, btn_styling, size_class(@size),
                @html_attrs[:class])
  end

  def link_html_options
    base = { class: merged_class }
    base = base.deep_merge(tooltip_data) if @icon
    base = base.deep_merge(confirm_data) if @confirm
    base = base.deep_merge(@html_attrs.except(:class))
    if @new_tab
      base[:target] = "_blank"
      base[:rel] = "noopener noreferrer"
    end
    base
  end

  def tooltip_data
    data = { tooltip_target: "tip", placement: "top", title: @name }
    data[:active_title] = @active_content if @active_content
    { title: @name, data: data }
  end

  def confirm_data
    { data: { turbo_confirm: @confirm } }
  end
end
