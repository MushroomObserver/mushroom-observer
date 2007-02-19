# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

class Observation < ActiveRecord::Base
  has_and_belongs_to_many :images
  has_and_belongs_to_many :species_lists
  belongs_to :thumb_image, :class_name => "Image", :foreign_key => "thumb_image_id"
  has_many :comments
  belongs_to :user
  has_one :rss_log
  belongs_to :name

  def log(msg, touch)
    if self.rss_log.nil?
      self.rss_log = RssLog.new
    end
    self.rss_log.addWithDate(msg, touch)
  end
  
  def orphan_log(entry)
    self.log(entry, false) # Ensures that self.rss_log exists
    self.rss_log.observation = nil
    self.rss_log.add(self.unique_text_name, false)
    self.rss_log.save
  end
  
  def touch
    @modified = Time.new
  end
  
  # Temporary storage for names.  This info really gets handled
  # by the Name object, but a value may need to be stored temporarily
  # before the Name object can be created.
  def text_name=(text_name)
    @text_name = text_name
  end
  
  # Choose the temporary storage if it exists over the saved name
  def text_name
    result = ''
    if self.instance_variables.member?('@text_name')
      result = @text_name
    else
      name = self.name
      if name
        result = name.search_name
      end
    end
    result
  end
  
  def unique_text_name
    "%s (%s)" % [self.text_name, self.id]
  end
  
  def base_name
    name = self.name
    result = ''
    if name
      result = name.observation_name
    else
      result = self.text_name
    end
    result
  end
  
  def unique_format_name
    name = self.name
    if name
      what = name.observation_name
    else
      what = self.text_name
    end
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
    result = nil
    if id != 0
      result = Image.find(id)
      if result
        self.add_image(result)
      end
    end
    result
  end

  def remove_image_by_id(id)
    img = nil
    if id != 0
      img = Image.find(id)
      if img
        img.observations.delete(self)
        if self.thumb_image_id == id.to_i
          if self.images != []
            self.thumb_image = self.images[0]
          else
            self.thumb_image_id = nil
          end
          self.save
        end
      end
    end
    img
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
  def self.all_observations
    find(:all,
         :order => "'when' desc")
  end

  validates_presence_of :user, :where

end
