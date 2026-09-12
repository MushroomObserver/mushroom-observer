# frozen_string_literal: true

# Modal-trigger `<a>` that opens a Bootstrap modal via the
# `modal-toggle` Stimulus controller. Plain link by default (no
# button styling); pass `button:` to add btn classes.
#
# The only non-ModalToggle caller is `ApplicationForm::AutocompleterField`,
# which needs a plain styled link (not a button) with icon support.
# All other callers should use `Components::Button::ModalToggle` instead.
class Components::Link::Modal < Components::Link
  prop :modal_id, String
  prop :name, String
  prop :path, String
  prop :icon, _Nilable(_Union(*Components::Button::ICONS)), default: nil
  prop :icon_class, _Nilable(String), default: nil
  prop :label, _Nilable(_Boolean), default: nil
  prop :size, _Nilable(_Union(*Components::Button::SIZES)), default: nil
  prop :attributes, _Hash(Symbol, _Any?), :**

  def initialize(modal_id:, name:, target:, **opts)
    icon       = opts.delete(:icon)
    icon_class = opts.delete(:icon_class)
    label      = opts.delete(:label)
    size       = opts.delete(:size)
    button     = opts.delete(:button)
    validate_no_btn_classes!(opts[:class])
    super(modal_id: modal_id, name: name, path: target, icon: icon,
          icon_class: icon_class, label: label, size: size, button: button,
          **opts)
  end

  def view_template
    if @icon
      Link(type: :get, name: @name, target: @path, **icon_link_args)
    else
      link_to(@name, @path, **plain_link_args)
    end
  end

  private

  def plain_link_args
    { class: merged_class }.
      merge(@attributes.except(:class)).
      deep_merge(data: modal_data)
  end

  def icon_link_args
    { icon: @icon, icon_class: @icon_class, label: @label,
      class: merged_class }.
      merge(@attributes.except(:class)).
      deep_merge(data: modal_data)
  end

  def merged_class
    class_names(btn_styling, size_class(@size), @attributes[:class])
  end

  def modal_data
    {
      modal: "modal_#{@modal_id}",
      controller: "modal-toggle",
      action: "modal-toggle#showModal:prevent"
    }
  end
end
