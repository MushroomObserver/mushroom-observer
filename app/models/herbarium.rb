class Herbarium < AbstractModel
  has_many :specimens
  belongs_to :location
  has_and_belongs_to_many :curators, :class_name => "User", :join_table => "herbaria_curators"
  
  # Used to allow location name to be entered as text in forms
  attr_accessor :place_name

  def is_curator?(user)
    user and curators.member?(user)
  end

  def label_free?(new_label)
    Specimen.find_all_by_herbarium_id_and_herbarium_label(self.id, new_label).count == 0
  end
end
