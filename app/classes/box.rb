# frozen_string_literal: true

# rectangle on the surface of the earth, whose borders are n, s, e, w
# used mostly (exclusively?) by model scopes
class Box
  attr :n, :s, :e, :w

  def initialize(n: nil, s: nil, e: nil, w: nil)
    @n = n
    @s = s
    @e = e
    @w = w
  end

  def valid?
    args_in_bounds? &&
    s <= n &&
    ((w <= e) || straddles_180_deg?)
  end

  def straddles_180_deg?
    w > e && (w >= 0 && e <= 0)
  end

  # Return a new box with edges expanded by delta
  # Useful for dealing with float rounding errors when
  # making comparisons to edges
  def expand(delta)
    Box.new(n: n + delta, s: s - delta, e: e + delta, w: w - delta)
  end

  ##############################################################################

  private

  def args_in_bounds?
    s&.between?(-90, 90) && n&.between?(-90, 90) &&
    w&.between?(-180, 180) && e&.between?(-180, 180)
  end
end
