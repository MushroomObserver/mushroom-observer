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
    #
    # 2.8rem, not 2.5rem: MO's own .glyphicon { font-size: 112%; }
    # (_icons.scss) already boosts the Current column's font glyph
    # 12% past the 2.5rem the wrapping div sets -- confirmed via
    # getComputedStyle (28px rendered vs. a 25px wrapper). Matching
    # that here, plus dropping the fit padding below from 8% to 2%,
    # closed the remaining gap on square/circular icons (circle-plus,
    # circle-question, alert) that the width:auto change alone
    # couldn't touch, since their aspect ratio is already ~1.
    svg(class: "sprite-icon-fit", style: "height: 2.8rem; width: auto;",
        xmlns: "http://www.w3.org/2000/svg") do
      path(d: @path_data, fill: "#262626")
    end
  end
end
