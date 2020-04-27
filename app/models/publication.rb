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
  belongs_to :user

  validate :check_requirements
  def check_requirements # :nodoc:
    unless user
      errors.add(:user, "missing user") # sign of internal error,
      # should never happen
    end
    errors.add(:full, :validate_publication_ref_missing.t) if full.blank?
  end

  # AbstractModel sets a non-rails default, needs to be overridden
  def self.show_controller
    "publications"
  end

end
