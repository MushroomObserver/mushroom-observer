# frozen_string_literal: true

#
#  = Publications Model
#
#  Publications which cite or benefit from Mushroom Observer
#
#  == Attributes
#
#  id::            Locally unique numerical id, starting at 1.
#  user_id::       id of user who created the entry
#  full::          Full name of publication
#  link::          URL of publication
#  how_helped::    Explanation of how publication was benefited by MO
#  mo_mentioned::  Whether publication mentions MO.  true/false
#  peer_reviewed:: Whether publication is peer reviewed.  true/false
#  created_at::    Date/time it was last updated.
#  updated_at::    Date/time it was last updated.
#
#  == Class methods
#
#  None
#
#  == Instance methods
#
#  None
#
#  == Callbacks
#
#  None.
#
################################################################################

class Publication < AbstractModel
  # Surface N+1s on `publication.user`; every caller must
  # eager-load this.
  self.strict_loading_by_default = true

  belongs_to :user

  validate :check_requirements
  def check_requirements # :nodoc:
    # Check the FK directly so strict_loading doesn't force an
    # extra `users` lookup during validation.
    unless user_id
      errors.add(:user, "missing user") # sign of internal error,
      # should never happen
    end
    errors.add(:full, :validate_publication_ref_missing.t) if full.blank?
  end
end
