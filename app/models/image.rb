#
#  Model for images.  Most images are, of course, mushrooms, but mugshots use
#  this class, as well.  They are indistinguishable at the moment.  Each image:
#
#  1. has a title
#  2. has a date ("when")
#  3. has notes
#  4. has a copyright ("copyright_holder" and "license")
#  5. is owned by a user
#  6. can belong to one to many Observation's and User's
#
#  Images are stored in
#    public/images/orig/#{id}.jpg       Originals.
#    public/images/640/#{id}.jpg        Large copies.
#    public/images/thumb/#{id}.jpg      Small copies.
#
#  Public Methods:
#
#    unique_format_name  Marked-up title.
#    unique_text_name    Plain-text title.
#    thumb_clients       Observations that use this image as their "thumnail".
#
#    image=              These three are used to upload a file.
#    get_image
#    save_image
#
#    original_image      Filename of original.
#    big_image           Filename of large copy.
#    thumbnail           Filename of thumbnail copy.
#
#    get_thumbnail       Read thumbnail into big string.
#    get_original        Read original into much bigger string.
#
################################################################################

class Image < ActiveRecord::Base
  has_and_belongs_to_many :observations
  has_many :thumb_clients, :class_name => "Observation", :foreign_key => "thumb_image_id"
  belongs_to :user
  belongs_to :license
  belongs_to :reviewer, :class_name => "User", :foreign_key => "reviewer_id"
  attr_accessor :img_dir

  # Returns: array of symbols.  Essentially a constant array.
  def self.all_qualities()
    [:unreviewed, :low, :medium, :high]
  end
  
  def unique_format_name
    obs_names = []
    self.observations.each {|o| obs_names.push(o.format_name)}
    title = obs_names.uniq.sort.join(' & ')
    if title
      sprintf("%s (%d)", title, self.id)
    else
      sprintf("Image %d", self.id)
    end
  end

  def unique_text_name
    obs_names = []
    self.observations.each {|o| obs_names.push(o.text_name)}
    title = obs_names.uniq.sort.join(' & ')
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
    @img_dir = IMG_DIR
  end

  def check_test(obs)
    if obs.id == 1
      { :checked => 'checked' }
    else
      { :checked => '' }
    end
  end

  def create_resized_images
    result = self.calc_size
    logger.warn("create_resized_images: Calculated size: #{@width}x#{@height}")
    if result
      self.resize_image(640, 640, self.big_image)
      self.resize_image(160, 160, self.thumbnail)
    end
    return result
  end

  # Can't include this in image= because self.id isn't set until first save
  def save_image
    file = File.new(self.original_image, 'w')
    file.print(@img)
    file.close
    return self.create_resized_images
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
      cmd = sprintf("convert -size %dx%d -quality 50 %s -resize %dx%d %s",
                    w, h, self.original_image, w, h, dest)
    else
      cmd = sprintf("cp %s %s", self.original_image, dest)
    end
    system cmd
    logger.warn(cmd)
  end

  def original_image
    sprintf("%s/orig/%d.jpg", self.img_dir, self.id)
  end

  def big_image
    sprintf("%s/640/%d.jpg", self.img_dir, self.id)
  end

  def thumbnail
    sprintf("%s/thumb/%d.jpg", self.img_dir, self.id)
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

  def get_original
    file = File.new(self.original_image, 'r')
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

  validates_format_of :content_type, :with => /^image/,
           :message => "You can only upload images."

  validates_presence_of :user

end
