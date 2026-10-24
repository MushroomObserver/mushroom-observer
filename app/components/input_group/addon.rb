# frozen_string_literal: true

module Components
  # A prepended or appended addon inside an `InputGroup`. BS4 wraps
  # every addon in an outer `.input-group-prepend`/`-append` (a flex
  # item of `.input-group` itself); a `Button`/`Link`/Superform
  # `submit` (`variant: :btn`, the default) sits directly inside that
  # wrapper, while a plain text addon (`variant: :addon`) needs one
  # more layer, `<span class="input-group-text">`, inside it.
  # `variant: :label` is the same shape but a `<label for:>` tied to
  # the group's input, with `.font-weight-normal` baked in -- the
  # sitewide `label { font-weight: bold }` rule would otherwise bold
  # it, unlike a `<span>` addon. A sibling of `InputGroup`, not a
  # "type" of it (no dispatching parent), so it's reached via full
  # `render(...)`, not Kit sugar — see `render()` example on
  # `Components::InputGroup`.
  class InputGroup::Addon < Base
    INNER_CLASS = { addon: "input-group-text",
                    label: "input-group-text font-weight-normal" }.freeze

    prop :variant, _Union(:btn, :addon, :label), default: :btn
    prop :position, _Union(:prepend, :append), default: :append
    # Only meaningful for `variant: :label` -- the id of the input
    # this label describes.
    prop :label_for, _Nilable(::String), default: nil
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template(&block)
      div(**wrapper_attributes) do
        case @variant
        when :label
          label(class: INNER_CLASS[:label], for: @label_for, &block)
        when :addon
          span(class: INNER_CLASS[:addon], &block)
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
