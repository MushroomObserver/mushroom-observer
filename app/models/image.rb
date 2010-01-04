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
  attr_accessor :img_dir, :content_length, :content_md5

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

  # Check uploaded file and make note of its temporary location.  It can take
  # a variety of argument types.  All must provide a few capabilities:
  #   image = file
  #   file.content_type
  #   file.content_length or size
  #
  # Apache waits
  # for all uploads to arrive before passing the request off to Rails.  It
  # stores them in /tmp somewhere until Rails is done with them.
  # (file is an ActionController::UploadedTempfile, which has
  # the method "original_filename", and inherits from Tempfile, which
  # has the methods "size", "path", "delete", etc. and inherits in turn
  # from File...)
  def image=(file)
    @img = file

    # This is the default.  Doing it this way allows us to override the default
    # while testing.
    self.img_dir = IMG_DIR

    # Try to determine the file size.
    if @img.respond_to?(:content_length)
      self.content_length = @img.content_length
    elsif @img.respond_to?(:size)
      self.content_length = @img.size
    else
      # require caller to set it explicitly
    end

    # Try to determine the file type.
    if @img.respond_to?(:content_type)
      self.content_type = file.content_type.chomp
    else
      # require caller to set it explicitly
    end

    return @img
  end

  # Move uploaded file into place and initiate resizing and transfers.
  # Can't include this in image= because self.id isn't set until first save.
  def save_image
    result = false
    if @img

      # Image is stored in a local file.  This is what Apache does with them.
      if @img.is_a?(ActionController::UploadedTempfile)
        begin
          raise(SystemCallError, "Don't move my test images!!") if TESTING
          result = true if File.rename(@img.path, original_image) and
                           File.chmod(0644, original_image) == 1
        rescue SystemCallError
          result = true if system('cp', @img.path, original_image)
        rescue => e
          errors.add(:image, e.to_s)
          result = false
        end

      # Image is supplied in a input stream.  This can happen in a variety of
      # cases, including during testing, and also when the image comes in as
      # the body of a request.
      elsif @img.is_a?(IO) || @img.is_a?(StringIO)
        begin
          File.open(original_image, 'w') do |fh|
            FileUtils.copy_stream(@img, fh)
          end
          result = true
        rescue => e
          errors.add(:image, e.to_s)
          result = false
        end

      # Raise an error for all other cases.
      else
        errors.add(:image, "Unexpected internal I/O type: #{@img.class}")
        result = false
      end

      if result
        # Check MD5 sum if supplied with image.
        if content_md5 && !(
           (sum = File.read("| md5sum #{original_image}")) &&
           (sum.split.first == content_md5)
        )
          errors.add(:image, "md5 sum doesn't match\ngot:    #{sum.split.first}\nexpect: #{content_md5}]")
          result = false
        end

#         # If we successfully received the raw image, spawn process to resize it
#         # and transfer it to image server.
#         if !system("script/process_image #{self.id}&")
#           errors.add(:image, 'Something went wrong when spawning process_image...')
#           result = false
#         end
      end
    end
    return result
  end

  # Destroy image and log destruction on all objects using it.  (Also change
  # thumbnails to another image whenever necessary.)
  def destroy(user)
    image_name = self.unique_format_name
    for obs in Observation.find_all_by_thumb_image_id(self.id, :include => :images)
      obs.log(:log_image_destroyed, { :user => user.login,
        :name => image_name }, true)
      obs.thumb_image = (obs.images - self).first
      obs.save
    end
    return super()
  end

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

  # Return URL for original image.
  def original_url
    sprintf("%s/orig/%d.jpg", IMAGE_DOMAIN, self.id)
  end

  # Return URL for 640x640 image.
  def big_url
    sprintf("%s/640/%d.jpg", IMAGE_DOMAIN, self.id)
  end

  # Return URL for thumbnail image.
  def thumbnail_url
    sprintf("%s/thumb/%d.jpg", IMAGE_DOMAIN, self.id)
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

    if content_length.to_i > IMAGE_UPLOAD_MAX_SIZE
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
