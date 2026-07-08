# frozen_string_literal: true

module Components
  # Bootstrap input-group wrapper: a `<div class="input-group">`
  # around one or more form controls plus `InputGroup::Addon` spans.
  # Reused across `index_pagination_nav.rb`'s page/letter-jump inputs
  # and `account/api_keys/form.rb`'s inline notes editors, and by the
  # `ApplicationForm::InputGroupAddon` mixin (`text_field(..., button:
  # ...)` / `addon: ...`) that decorates a single Superform field.
  #
  # BS4 renames `.input-group-btn` to `.input-group-append` (or
  # `-prepend`) and BS5 drops the wrapping span entirely (addons
  # become plain direct children) — `InputGroup`/`InputGroup::Addon`
  # are the two places that swap happens.
  #
  # @example
  #   InputGroup(class: "page-input mx-2") do
  #     input(type: :text, name: :page)
  #     render(Components::InputGroup::Addon.new) do
  #       Button(type: :submit) { "Go" }
  #     end
  #   end
  class InputGroup < Base
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template(&block)
      div(**group_attributes, &block)
    end

    private

    def group_attributes
      {
        class: class_names("input-group", @attributes[:class]),
        **@attributes.except(:class)
      }
    end
  end
end
