# frozen_string_literal: true

# Translation-key shortcuts for enum-like model attributes. Each
# method is a one-line `:"#{prefix}_#{value}".l` lookup — pulled into
# a single module so callers across components and views go through
# one named API instead of inlining the symbol-build dance everywhere.
#
# Included into `Components::Base` so every Phlex view / component
# has them available as plain methods (no helper proxy).
module Components::Localization
  # `Name#rank` → singular translation, e.g. `:genus` → "Genus".
  def rank_as_string(rank)
    :"RANK_#{rank.to_s.upcase}".l
  end

  # `Image#vote_cache` → longer translation including the "good
  # enough for a field guide" sentence. Returns textile source —
  # callers run `.t` after.
  def image_vote_as_long_string(val)
    :"image_vote_long_#{val || 0}".l
  end

  # `Image#vote_cache` → "Good enough for a field guide."-shaped
  # translation (no textile).
  def image_vote_as_help_string(val)
    :"image_vote_help_#{val || 0}".l
  end

  # `Image#vote_cache` → short label like "Good".
  def image_vote_as_short_string(val)
    :"image_vote_short_#{val || 0}".l
  end
end
