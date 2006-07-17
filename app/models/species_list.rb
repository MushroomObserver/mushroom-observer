class SpeciesList < ActiveRecord::Base
  has_and_belongs_to_many :observations
  belongs_to :user

  def species
    ''
  end
  
  def species=(list)
  end
  
  def unique_name
    title = self.title
    if title
      sprintf("%s (%d)", title[0..(MAX_FIELD_LENGTH-1)], self.id)
    else
      sprintf("Species List %d", self.id)
    end
  end
      
end
