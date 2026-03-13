# frozen_string_literal: true

# Form object for propagating lifeform tags to children
# Has add_* and remove_* attributes for each lifeform
class FormObject::PropagateLifeform < FormObject::Base
  # Define add_* attributes for lifeforms currently on the name
  # Define remove_* attributes for lifeforms not on the name
  Name::Lifeform::ALL_LIFEFORMS.each do |word|
    attribute :"add_#{word}", :boolean, default: false
    attribute :"remove_#{word}", :boolean, default: false
  end

  # Tell Superform to use PUT method (this is an update action)
  def persisted?
    true
  end
end
