class Image < ActiveRecord::Base
  has_and_belongs_to_many :observations
  has_many :thumb_clients, :class_name => "Observation", :foreign_key => "thumb_image_id"

  validates_format_of :content_type, :with => /^image/,
           :message => "--- you can only upload images"

  def unique_name
    title = self.title
    if title
      sprintf("%s (%d)", title, self.id)
    else
      sprintf("Image %d", self.id)
    end
  end

  def image=(image_field)
    self.content_type = image_field.content_type.chomp
    @img = image_field.read
    @width = false
    @height = false
  end

  def check_test(obs)
    if obs.id == 1
      { :checked => 'checked' }
    else
      { :checked => '' }
    end
  end

  # Can't include this in image= because self.id isn't set until first save
  def save_image
    logger.warn("save_image: #{self.original_image}")
    file = File.new(self.original_image, 'w')
    file.print(@img)
    file.close
    logger.warn("save_image: Wrote original")
    result = self.calc_size
    logger.warn("save_image: Calculated size: #{@width}x#{@height}")
    if result
      self.resize_image(640, 640, self.big_image)
      self.resize_image(100, 100, self.thumbnail)
    end
    return result
  end

  def resize_image(width, height, dest)
    r1 = width/Float(@width)
    r2 = height/Float(@height)
    if r1 < r2
      ratio = r1
    else
      ratio = r2
    end
    if ratio < 1
      w = ratio*@width
      h = ratio*@height
      cmd = sprintf("convert -size %dx%d -quality 75 %s -resize %dx%d %s",
                    w, h, self.original_image, w, h, dest)
    else
      cmd = sprintf("cp %s %s", self.original_image, dest)
    end
    system cmd
    logger.warn(cmd)
  end

  def original_image
    sprintf("%s/orig/%d.jpg", IMG_DIR, self.id)
  end

  def big_image
    sprintf("%s/640/%d.jpg", IMG_DIR, self.id)
  end

  def thumbnail
    sprintf("%s/thumb/%d.jpg", IMG_DIR, self.id)
  end

  IDENTIFY_PAT = /^\S+ \w+ (\d+)x(\d+)/

  def calc_size
    result = true
    unless @width
      image_data = `identify #{self.original_image}`
      if image_data
        match = IDENTIFY_PAT.match(image_data)
        if match
          @width = match[1].to_i
          @height = match[2].to_i
        end
      end
    end
    unless @width
      logger.warn("Unable to extract image size from #{self.original_image}")
      result = false
    end
    result
  end

  def get_thumbnail
    file = File.new(self.thumbnail, 'r')
    result = file.read
    file.close
    result
  end

  def get_image
    unless @img
      file = File.new(self.big_image, 'r')
      @img = file.read
      self.calc_size
      file.close
    end
    @img
  end

  def base_part_of(file_name)
    name = File.basename(file_name)
    name.gsub(/[^\w._-]/, '')
  end
end
