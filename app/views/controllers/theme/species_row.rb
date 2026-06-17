# frozen_string_literal: true

module Views::Controllers::Theme
  # One row of a theme page's SPECIES constant.
  #
  # `textile_method` is `:tp` (textile-paragraph) or `:t` (textile-
  # inline) — the per-row choice between rendering as a paragraph
  # or just inline textile.
  # `key` is the en.txt symbol whose translation has an `[link]`
  # placeholder.
  # `name` is the species name displayed as the link label.
  # `image_id` is the Image the link targets.
  # `list_line` is the wrapping `<span>` CSS class, or `nil` for raw.
  # `raw_link_label`: if true, use `name` as-is instead of wrapping
  # in textile bold+italic markers (`**__name__**`).
  SpeciesRow = Data.define(:textile_method, :key, :name, :image_id,
                           :list_line, :raw_link_label) do
    def self.[](textile_method, key, name, image_id, opts = {})
      new(textile_method: textile_method, key: key, name: name,
          image_id: image_id, list_line: opts[:list_line],
          raw_link_label: opts.fetch(:raw_link_label, false))
    end
  end
end
