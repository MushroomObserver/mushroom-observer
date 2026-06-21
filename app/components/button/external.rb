# frozen_string_literal: true

# Button-styled anchor that opens an external URL in a new tab
# (`target="_blank" rel="noopener noreferrer"`). Rendered when the
# context-nav dispatcher sees `external: true` + `button: :get` on a
# tab's html_options, or called directly for prominent external links.
#
# @example Sequence BLAST link
#   render(Components::Button::External.new(
#     name: :show_observation_blast_link.l,
#     url: @sequence.blast_url
#   ))
class Components::Button::External < Components::Button
  def initialize(url:, name:, **)
    super(name: name, tag: :a,
          href: url, target: "_blank", rel: "noopener noreferrer",
          **)
  end
end
