class Observation < ActiveRecord::Base
  has_and_belongs_to_many :images
  belongs_to :thumb_image, :class_name => "Image", :foreign_key => "thumb_image_id"

  validates_presence_of :who, :where

  def touch
    @modified = Time.new
  end

  def unique_name
    what = self.what
    if what
      sprintf("%s (%d)", what, self.id)
    else
      sprintf("Observation %d", self.id)
    end
  end

  def add_image(img)
    img.observations << self
    logger.warn(self.thumb_image_id)
    unless self.thumb_image
      logger.warn("**** Setting observation.thumb_image")
      self.thumb_image = img
    end
  end

  protected
  def validate
    errors.add(:notes,
               "at least one of Notes, What or Image must be provided") if
      ((notes.nil? || notes=='') &&
         (what.nil? || what==''))
  end

  def self.all_observations
    find(:all,
         :order => "'when' desc")
  end
end
