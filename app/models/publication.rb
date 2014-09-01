# encoding: utf-8

class Publication < AbstractModel
  belongs_to :user

  validate :check_requirements
  def check_requirements # :nodoc:
    if !user
      errors.add(:user, 'missing user') # sign of internal error, should never happen
    end
    if full.blank?
      errors.add(:full, :validate_publication_ref_missing.t)
    end
  end
end
