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
  
  # Create Textile title for image from observations, appending image id to
  # guarantee uniqueness. 
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

  # Create plain-text title for image from observations, appending image id to
  # guarantee uniqueness. 
  def unique_text_name
    obs_names = []
    self.observations.each {|o| obs_names.push(o.text_name)}
    title = obs_names.uniq.sort.join(' & ')
    if obs_names.empty?
      sprintf("%s #%d", :image.l, self.id)
    else
      sprintf("%s (%d)", title, self.id)
    end
  end

  # Check uploaded file and make note of its temporary location.  Apache waits
  # for all uploads to arrive before passing the request off to Rails.  It
  # stores them in /tmp somewhere until Rails is done with them. 
  def image=(file)
    self.content_type = file.content_type.chomp
    @img_dir = IMG_DIR
    if NEW_IMAGE_THINGY
      # (file is an ActionController::UploadedTempfile, which has
      # the method "original_filename", and inherits from Tempfile, which
      # has the methods "size", "path", "delete", etc. and inherits in turn
      # from File...)
      @img = file
      @img = :too_big if @img.size > IMAGE_UPLOAD_MAX_SIZE
    else
print "111111111111111> Got here.\n"
      @img = file.read
    end
  end

  # Move uploaded file into place and initiate resizing and transfers.
  # Can't include this in image= because self.id isn't set until first save.
  def save_image
    result = false
    if NEW_IMAGE_THINGY
      if @img
        begin
          raise(SystemCallError, "Don't move my test images!!") if TESTING
          result = true if File.rename(@img.path, self.original_image)
        rescue SystemCallError
          result = true if system('cp', @img.path, self.original_image)
        rescue => err
          result = false
        end
        result = system("script/process_image #{self.id}&") if result
      end
    else
print "222222222222222> Got here.\n"
      file = File.new(self.original_image, 'w')
      file.print(@img)
      file.close
      result = self.create_resized_images
print "333333333333333> #{result}\n"
      result = self.transfer_images if result
print "444444444444444> #{result}\n"
    end
    return result
  end

###############################################################################
###### These are going away as soon as NEW_IMAGE_THINGY is tested live. #######
###############################################################################

  # Convert original into 640x640 and 160x160 images.
  def create_resized_images
    result = true
    result = self.resize_image(640, 640, 70, self.original_image, self.big_image)
    if result
      result = self.resize_image(160, 160, 90, self.big_image, self.thumbnail)
    end
    return result
  end

  # Resize +src+ image and save as +dest+, stripping headers.
  def resize_image(width, height, quality, src, dest)
    result = false
    cmd = sprintf("convert -thumbnail '%dx%d>' -quality %d %s %s",
                   width, height, quality, src, dest)
    if File.exists?(src) and result = system(cmd)
      logger.warn(cmd + ' -- success')
    else
      logger.warn(cmd + ' -- failed')
    end
    return result
  end

  # Copy images over to dreamhost via scp.
  def transfer_images
    self.transfer_image(self.original_image)
    self.transfer_image(self.big_image)
    self.transfer_image(self.thumbnail)
  end

  # Transfer new image to the image server.
  def transfer_image(src)
    result = false
    if !IMAGE_TRANSFER
      result = true
    elsif File.exists?(src)
      if src.match(/\w+\/\d+\.jpg$/)
        dest = $&
        cmd = "scp %s %s/%s" % [src, IMAGE_SERVER, dest]
        result = system cmd
        if result
          logger.warn(cmd + ' -- success')
        else
          logger.warn(cmd + ' -- failed')
        end
      end
    end
    return result
  end

################################################################################

  # Return file name of original image.
  def original_image
    sprintf("%s/orig/%d.jpg", self.img_dir, self.id)
  end

  # Return file name of 640x640 image.
  def big_image
    sprintf("%s/640/%d.jpg", self.img_dir, self.id)
  end

  # Return file name of thumbnail image.
  def thumbnail
    sprintf("%s/thumb/%d.jpg", self.img_dir, self.id)
  end

  # Read thumbnail into a buffer and return it.
  def get_thumbnail
    file = File.new(self.thumbnail, 'r')
    result = file.read
    file.close
    result
  end

  # Read original image into a buffer and return it. (!!)
  def get_original
    file = File.new(self.original_image, 'r')
    result = file.read
    file.close
    result
  end

  # Take filename, remove path and extension, then remove weird characters.
  def base_part_of(file_name)
    name = File.basename(file_name)
    name.gsub(/[^\w._-]/, '')
  end

  protected

  def validate # :nodoc:
    if !self.user
      errors.add(:user, :validate_image_user_missing.t)
    end
    if !self.when
      errors.add(:when, :validate_image_when_missing.t)
    end

    if !self.content_type.to_s.match(/^image/)
      errors.add(:content_type, :validate_image_content_type_images_only.t)
    elsif self.content_type.to_s.length > 100
      errors.add(:content_type, :validate_image_content_type_too_long.t)
    end

    if @img == :missing
      errors.add(:image, :validate_image_file_missing.t)
    elsif @img == :too_big
      errors.add(:image, :validate_image_file_too_big.t(:max => IMAGE_UPLOAD_MAX_SIZE.to_s.sub(/\d{6}$/, 'Mb')))
    end

    if self.title.to_s.length > 100
      errors.add(:title, :validate_image_title_too_long.t)
    end
    if self.copyright_holder.to_s.length > 100
      errors.add(:copyright_holder, :validate_image_copyright_holder_too_long.t)
    end
  end
end
