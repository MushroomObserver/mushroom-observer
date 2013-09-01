class Term < AbstractModel
  belongs_to :thumb_image, :class_name => "Image", :foreign_key => "thumb_image_id"
  belongs_to :user
  has_and_belongs_to_many :images

  ALL_TERM_FIELDS = [:name, :description]
  acts_as_versioned(
    :table_name => 'terms_versions',
    :if_changed => ALL_TERM_FIELDS,
    :association_options => { :dependent => :orphan }
  )
  non_versioned_columns.push(
    'thumb_image_id',
    'created_at',
  )
  versioned_class.before_save {|x| x.user_id = User.current_id}

  # Probably should add a user_id and a log
  # versioned_class.before_save {|x| x.user_id = User.current_id}

  # Override the default show_controller
  def self.show_controller
    'glossary'
  end

  def text_name
    self.name
  end
  
  def format_name
    self.name
  end
  
  def add_image(image)
    if image
      self.thumb_image = image if self.thumb_image.nil?
      self.images.push(image)
    end
  end
end
