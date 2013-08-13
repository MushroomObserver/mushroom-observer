class Term < ActiveRecord::Base
  belongs_to :image         # mug shot

  def text_name
    self.name
  end
  
  def format_name
    self.name
  end
  
  def add_image(image)
    self.image = image if image
  end
end
