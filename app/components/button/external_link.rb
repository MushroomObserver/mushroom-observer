# frozen_string_literal: true

# Button-styled link to an external URL. Always opens in a new tab
# (`target="_blank" rel="noopener noreferrer"`). Use this instead of
# `Button.new(tag: :a, href: ...)` when the destination is off-site.
#
# `url:` is named separately from `Button::Get`'s `target:` to avoid
# the kwarg collision that would arise from both CRUDBase's model/URL
# target and the HTML `target` attribute.
#
# @example NCBI BLAST link on a Sequence show page
#   render(Components::Button::ExternalLink.new(
#     name: :show_observation_blast_link.l,
#     url: @sequence.blast_url
#   ))
class Components::Button::ExternalLink < Components::Button
  def initialize(url:, name:, **)
    super(name: name, tag: :a,
          href: url, target: "_blank", rel: "noopener noreferrer",
          **)
  end
end
