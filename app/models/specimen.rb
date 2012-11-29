class Specimen < AbstractModel
  belongs_to :herbarium
  belongs_to :user
  has_and_belongs_to_many :observations
  
  # Used to allow location name to be entered as text in forms
  attr_accessor :herbarium_name
  
  def can_edit?(user)
    user and ((self.user == user) or herbarium.is_curator?(user))
  end
end
