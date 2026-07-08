# frozen_string_literal: true

module Components
  # The trailing (or leading) `<span>` inside an `InputGroup` — wraps
  # a `Button`, `Link`, or Superform `submit` (`variant: :btn`, the
  # default, emitting `.input-group-btn`), or a plain text addon
  # (`variant: :addon`, emitting `.input-group-addon`). A genuine
  # sibling of `InputGroup`, not a "type" of it (no dispatching
  # parent), so it's reached via full `render(...)`, not Kit sugar —
  # see `render()` example on `Components::InputGroup`.
  class InputGroup::Addon < Base
    VARIANT_CLASSES = {
      btn: "input-group-btn",
      addon: "input-group-addon"
    }.freeze

    prop :variant, _Union(:btn, :addon), default: :btn
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template(&block)
      span(**addon_attributes, &block)
    end

    private

    def addon_attributes
      {
        class: class_names(VARIANT_CLASSES[@variant], @attributes[:class]),
        **@attributes.except(:class)
      }
    end
  end
end
