class Specimen < AbstractModel
  belongs_to :herbarium
  has_and_belongs_to_many :observations
end
