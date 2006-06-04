# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

class Observation < ActiveRecord::Base
  has_and_belongs_to_many :images
  belongs_to :thumb_image, :class_name => "Image", :foreign_key => "thumb_image_id"
  has_many :comments

  validates_presence_of :who, :where

  def touch
    @modified = Time.new
  end

  def unique_name
    what = self.what
    if what
      sprintf("%s (%d)", what[0..(MAX_FIELD_LENGTH-1)], self.id)
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

  def add_image_by_id(id)
    if id != 0
      img = Image.find(id)
      if img
        self.add_image(img)
      end
    end
  end

  def remove_image_by_id(id)
    if id != 0
      img = Image.find(id)
      if img
        img.observations.delete(self)
      end
    end
  end

  def idstr
    ''
  end
  
  def idstr=(id_field)
    id = id_field.to_i
    img = Image.find(:id => id)
    unless img
      errors.add(:notes, "unable to find a corresponding image")
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
