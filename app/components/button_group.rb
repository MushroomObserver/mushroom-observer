# frozen_string_literal: true

module Components
  # Bootstrap button-group wrapper: a `<div class="btn-group"
  # role="group">` around a row of visually-connected buttons/links.
  # Reused across `rss_logs/type_filters.rb`, `visual_groups/edit.rb`,
  # and `interests/index.rb` — all plain visual grouping (no
  # `data-toggle="buttons"` checkbox/radio JS behavior). Always emits
  # `role="group"` (one of the three raw call sites this replaces was
  # missing it) — pass `role:` explicitly to override for the rare
  # case of nesting inside a `.btn-toolbar`.
  #
  # `.btn-group` itself doesn't rename across BS3/4/5, so this
  # component exists for DRY + accessibility consistency, not to
  # absorb a future class-rename.
  #
  # @example
  #   ButtonGroup do
  #     Button(name: "All", ...)
  #     Button(name: "Mine", ...)
  #   end
  class ButtonGroup < Base
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template(&block)
      div(**group_attributes, &block)
    end

    private

    def group_attributes
      {
        class: class_names("btn-group", @attributes[:class]),
        role: @attributes[:role] || "group",
        **@attributes.except(:class, :role)
      }
    end
  end
end
