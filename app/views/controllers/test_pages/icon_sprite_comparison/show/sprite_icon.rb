# frozen_string_literal: true

# One <svg><path/></svg> fragment for the icon-sprite comparison page.
# A real Phlex::SVG subclass (not Phlex::HTML) -- Phlex::HTML only
# registers the bare <svg> wrapper tag, not nested SVG elements like
# <path>. Rendered via the ordinary `render(...)` from the parent
# Phlex::HTML view; Phlex shares one output buffer across component
# types, so this composes normally.
class Views::Controllers::TestPages::IconSpriteComparison::Show::
      SpriteIcon < Phlex::SVG
  def initialize(path_data:)
    super()
    @path_data = path_data
  end

  def view_template
    # Initial size is a placeholder -- TestPages::IconSpriteSvg's
    # bbox-fit script overrides both width and height per icon once it
    # knows the icon's own aspect ratio (object-fit: contain into a
    # 2.8rem square; see that file for why a single fixed dimension
    # doesn't work for every icon).
    svg(class: "sprite-icon-fit", style: "height: 2.8rem; width: 2.8rem;",
        xmlns: "http://www.w3.org/2000/svg") do
      path(d: @path_data, fill: "#262626")
    end
  end
end
