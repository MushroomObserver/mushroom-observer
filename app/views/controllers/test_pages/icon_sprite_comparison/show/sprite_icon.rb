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
    # height only, width auto -- forcing an exact-square box (the
    # earlier width+height: 2.5rem) letterboxed every non-square icon
    # under the SVG's default "meet" scaling, wasting real width/height
    # that a font glyph's own advance-width never has to give up.
    # Confirmed live: this alone closed most of the "SVG looks smaller
    # than the font glyph" gap across eye/bin/chevron-last-left.
    svg(class: "sprite-icon-fit", style: "height: 2.5rem; width: auto;",
        xmlns: "http://www.w3.org/2000/svg") do
      path(d: @path_data, fill: "#262626")
    end
  end
end
