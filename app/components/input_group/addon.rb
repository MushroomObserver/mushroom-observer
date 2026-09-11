# frozen_string_literal: true

module Components
  # A prepended or appended addon inside an `InputGroup`. BS4 wraps
  # every addon in an outer `.input-group-prepend`/`-append` (a flex
  # item of `.input-group` itself); a `Button`/`Link`/Superform
  # `submit` (`variant: :btn`, the default) sits directly inside that
  # wrapper, while a plain text addon (`variant: :addon`) needs one
  # more layer, `<span class="input-group-text">`, inside it. A
  # sibling of `InputGroup`, not a "type" of it (no dispatching
  # parent), so it's reached via full `render(...)`, not Kit sugar —
  # see `render()` example on `Components::InputGroup`.
  class InputGroup::Addon < Base
    INNER_CLASS = { addon: "input-group-text" }.freeze

    prop :variant, _Union(:btn, :addon), default: :btn
    prop :position, _Union(:prepend, :append), default: :append
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template(&block)
      div(**wrapper_attributes) do
        if INNER_CLASS[@variant]
          span(class: INNER_CLASS[@variant], &block)
        else
          yield
        end
      end
    end

    private

    def wrapper_attributes
      {
        class: class_names("input-group-#{@position}", @attributes[:class]),
        **@attributes.except(:class)
      }
    end
  end
end
