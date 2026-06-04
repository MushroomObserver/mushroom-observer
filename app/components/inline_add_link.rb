# frozen_string_literal: true

# Inline `[<ModalLink>]` — single "add new" link wrapped in
# brackets. Used by obs-show sub-panel headers
# ("Collection numbers: [+]", "Herbarium records: [+]", etc.)
# and the empty-state "[ + ]" prompts ("No collection numbers
# yet [+]") in the same panels.
#
# Sibling to `Components::InlineModLinks` (the
# `[ edit | destroy ]` group). Same bracket-flush-with-button
# spacing — the link's icon carries `link-icon px-2` so the
# brackets sit directly against the icon.
#
# @example
#   render(Components::InlineAddLink.new(
#     modal_id: "collection_number",
#     tab: ::Tab::CollectionNumber::New.new(observation: @obs)
#   ))
#
class Components::InlineAddLink < Components::Base
  prop :modal_id, String
  prop :tab, ::Tab::Base

  def view_template
    plain("[")
    name, path, opts = @tab.to_a
    render(Components::ModalLink.new(@modal_id, name, path, **opts))
    plain("]")
  end
end
