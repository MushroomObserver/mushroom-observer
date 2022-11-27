# frozen_string_literal: true

module LocalizationHelper
  # Translate Name rank (singular).
  #
  #   rank_as_string(:genus)  -->  "Genus"
  #
  def rank_as_string(rank)
    :"RANK_#{rank.to_s.upcase}".l
  end

  # Translate Name rank (singular).
  #
  #   rank_as_lower_string(:genus)  -->  "genus"
  #
  def rank_as_lower_string(rank)
    :"rank_#{rank.to_s.downcase}".l
  end

  # Translate Name rank (plural).
  #
  #   rank_as_plural_string(:genus)  -->  "Genera"
  #
  def rank_as_plural_string(rank)
    :"RANK_PLURAL_#{rank.to_s.upcase}".l
  end

  # Translate Name rank (plural).
  #
  #   rank_as_plural_string(:genus)  -->  "genera"
  #
  def rank_as_lower_plural_string(rank)
    :"rank_plural_#{rank.to_s.downcase}".l
  end

  # Translate image quality.
  #
  #   image_vote_as_long_string(3)  -->  "**Good** enough for a field guide."
  #
  def image_vote_as_long_string(val)
    :"image_vote_long_#{val || 0}".l
  end

  # Translate image quality.
  #
  #   image_vote_as_help_string(3)  -->  "Good enough for a field guide."
  #
  def image_vote_as_help_string(val)
    :"image_vote_help_#{val || 0}".l
  end

  # Translate image quality.
  #
  #   image_vote_as_short_string(3)  -->  "Good"
  #
  def image_vote_as_short_string(val)
    :"image_vote_short_#{val || 0}".l
  end

  # Translate review status.
  #
  #   review_as_string(:unvetted)  -->  "Reviewed"
  #
  def review_as_string(val)
    :"review_#{val}".l
  end

  # Determine the right string for visual group status from booleans
  # indicating if the image needs review (no VisualGroupImage exists),
  # is marked as included or not.
  def visual_group_status_text(status)
    return :visual_group_needs_review.t if status.nil?
    return :visual_group_include.t if status && (status != 0)

    :visual_group_exclude.t
  end
end
