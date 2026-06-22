# frozen_string_literal: true

# Modal-trigger `<a>` that opens a Bootstrap modal via the
# `modal-toggle` Stimulus controller. Plain link by default (no
# button styling); pass `button:` to add btn classes.
#
# The only non-ModalToggle caller is `ApplicationForm::AutocompleterField`,
# which needs a plain styled link (not a button) with icon support.
# All other callers should use `Components::Button::ModalToggle` instead.
class Components::Link::Modal < Components::Link
  def initialize(modal_id:, name:, target:, **opts)
    @modal_id   = modal_id
    @name       = name
    @path       = target
    @icon       = opts.delete(:icon)
    @icon_class = opts.delete(:icon_class)
    @show_text  = opts.delete(:show_text)
    button      = opts.delete(:button)
    @html_attrs = opts
    validate_no_btn_classes!(@html_attrs[:class])
    super(button: button)
  end

  def view_template
    if @icon
      render(Components::Link::Icon.new(@name, @path, **icon_link_args))
    else
      link_to(@name, @path, **plain_link_args)
    end
  end

  private

  def plain_link_args
    { class: merged_class }.
      merge(@html_attrs.except(:class)).
      deep_merge(data: modal_data)
  end

  def icon_link_args
    { icon: @icon, icon_class: @icon_class, show_text: @show_text,
      class: merged_class }.
      merge(@html_attrs.except(:class)).
      deep_merge(data: modal_data)
  end

  def merged_class
    class_names(btn_styling, @html_attrs[:class])
  end

  def modal_data
    {
      modal: "modal_#{@modal_id}",
      controller: "modal-toggle",
      action: "modal-toggle#showModal:prevent"
    }
  end
end
