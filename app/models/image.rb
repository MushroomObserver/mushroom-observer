#
#  = Image Model
#
#  Most images are, of course, mushrooms, but mugshots use
#  this class, as well.  They are indistinguishable at the moment.
#
#  == Files
#
#  The actual image is stored in three files:
#
#    RAILS_ROOT/public/images/orig/id.jpg
#    RAILS_ROOT/public/images/640/id.jpg
#    RAILS_ROOT/public/images/thumb/id.jpg
#
#  They are also being transferred to a remote image server with more disk
#  space: (images take up 100 Gb as of Jan 2010)
#
#    IMAGE_DOMAIN/orig/id.jpg
#    IMAGE_DOMAIN/640/id.jpg
#    IMAGE_DOMAIN/thumb/id.jpg
#
#  After the images are successfully transferred, we remove the originals from
#  the web server (see scripts/update_images).
#
#  == Upload
#
#  The execution flow from creating a new Image record to finish is:
#
#  1. Instantiate new Image record, filling in date, notes, etc.:
#
#       image = Image.new(
#         :created => Time.now,
#         :user    => @user,
#         :when    => observation.when,
#         :notes   => 'close-up of stipe'
#       )
#
#  2. Attach the image itself by setting to +image+ attribute, then save the
#     Image record:
#
#       # via HTTP form:
#       image.image = params[:image][:upload]
#       image.save
#
#       # via local file:
#       image.image = File.open('file.jpg')
#       image.save
#
#  3. After the record is saved, it knows the id so it can finally write out
#     the original image:
#
#       RAILS_ROOT/public/images/orig/id.jpg
#
#  4. Now it forks off a tiny shell script that takes care of the rest:
#
#       script/process_image $id
#
#  5. First it fills in the normal-size and thumbnail images with a
#     place-holder:
#
#       cd RAILS_ROOT/public/images
#       cp place_holder_640.jpg   640/$id.jpg
#       cp place_holder_thumb.jpg thumb/$id.jpg
#
#  6. Next it resizes the original twice to create real normal-size and
#     thumbnail images: (uses ImageMagick)
#
#       convert -thumbnail '160x160>' -quality 90 orig/$id.jpg thumb/$id.jpg
#       convert -thumbnail '640x640>' -quality 70 orig/$id.jpg 640/$id.jpg
#
#  7. Lastly it transfers all three images to the image server:
#
#       scp orig/$id.jpg  IMAGE_DOMAIN/orig/$id.jpg
#       scp 640/$id.jpg   IMAGE_DOMAIN/640/$id.jpg
#       scp thumb/$id.jpg IMAGE_DOMAIN/thumb/$id.jpg
#
#     (If any errors occur in +script/process_image+ they get emailed to the
#     webmasters.)
#
#  8. A nightly process runs to check for mistakes and remove any images that
#     have been successfully transferred:
#
#       script/update_images --clean
#
#     Currently it only removes originals, leaving thumbnail and normal-size
#     images on the web server.  [Also, for unknown reasons, +update_images+
#     doesn't actually delete anything?! -JPH 20100114]
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  sync_id::            Globally unique alphanumeric id, used to sync with remote servers.
#  created::            Date/time it was first created.
#  modified::           Date/time it was last modified.
#  user::               User that created it.
#  when::               Date image was taken.
#  notes::              Arbitrary notes (string of any length).
#  content_type::       MIME type of original image (the rest are 'image/jpeg').
#  copyright_holder::   Copyright holder (defaults to legal name of owner).
#  license::            License.
#  quality::            Quality (e.g., :low, :medium, :high).
#  reviewer::           User that reviewed it.
#  num_views::          Number of times normal-size image has been viewed.
#  last_view::          Last time normal-size image was viewed.
#
#  ==== Temporary attributes
#
#  img_dir::            Where images are stored (default is IMG_DIR).
#  content_length::     Length of original image file (if available).
#  content_md5::        MD5 hash of original image file (if available).
#
#  == Class Methods
#
#  all_qualities::      Allowed values for +quality+ (Array of Aymbol's).
#
#  == Instance Methods
#
#  unique_format_name:: Marked-up title.
#  unique_text_name::   Plain-text title.
#  observations::       Observations that use this image.
#  thumb_clients::      Observations that use this image as their "thumbnail".
#  ---
#  image=::             Attach an image (via IO stream or UploadedTempfile).
#  save_image::         Call this after saving new record to process image.
#  ---
#  original_image::     Filename of original image.
#  big_image::          Filename of normal-size image.
#  thumbnail::          Filename of thumbnail.
#  original_url::       URL of original image.
#  big_url::            URL of normal-size image.
#  thumbnail_url::      URL of thumbnail.
#
#  == Callbacks
#
#  log_destruction      Log destruction and change thumbnails before destroy.
#
################################################################################

class Image < AbstractModel
  has_and_belongs_to_many :observations
  has_many :thumb_clients, :class_name => "Observation", :foreign_key => "thumb_image_id"
  belongs_to :user
  belongs_to :license
  belongs_to :reviewer, :class_name => "User", :foreign_key => "reviewer_id"
  attr_accessor :img_dir, :content_length, :content_md5

  before_destroy :log_destruction

  # Array of allowed values for +review+ (Symbol's).
  #
  #   raise unless Image.all_qualities.include? :medium
  #
  def self.all_qualities
    [:unreviewed, :low, :medium, :high]
  end

  # Create plain-text title for image from observations, appending image id to
  # guarantee uniqueness.  Examples:
  #
  #   "Image #1"
  #   "Amanita lanei (Murr.) Sacc. & Trott. (2)"
  #   "Agaricus campestris L. & Agaricus californicus Peck. (3)"
  #
  def unique_text_name
    title = observations.map(&:text_name).uniq.sort.join(' & ')
    if title.blank?
      sprintf("%s #%d", :image.l, id)
    else
      sprintf("%s (%d)", title, id)
    end
  end

  # Create Textile title for image from Observation's, appending Image id to
  # guarantee uniqueness.  Examples:
  #
  #   "Image #1"
  #   "**__Amanita lanei__** (Murr.) Sacc. & Trott. (2)"
  #   "**__Agaricus campestris__** L. & **__Agaricus californicus__** Peck. (3)"
  #
  def unique_format_name
    title = observations.map(&:format_name).uniq.sort.join(' & ')
    if title.blank?
      sprintf("%s #%d", :image.l, id)
    else
      sprintf("%s (%d)", title, id)
    end
  end

  # Callback that logs destruction before Image is destroyed.  (Also change
  # thumbnail Observation's to another Image whenever necessary.)
  def log_destruction
    if user = User.current
      image_name = unique_format_name
      for obs in observations
        obs.log(:log_image_destroyed, :name => image_name)
        if obs.thumb_image_id == id
          obs.thumb_image = (obs.images - self).first
          obs.save
        end
      end
    end
  end

  # Check uploaded file and make note of its temporary location.  It can take
  # a variety of argument types.  All must provide a few capabilities:
  #
  #   img.image = file
  #
  #   # Must supply MIME type, e.g., 'image/tiff'.
  #   file.content_type
  #
  #   # Must supply length via one of these two:
  #   file.size
  #   file.content_length
  #
  # Additionally, if you have access to the MD5 hash, you can inform the Image
  # record of that at any time before calling +save_image+:
  #
  #   # (syntax of HTTP.get is probably wrong)
  #   request = Net::HTTP.get(uri, domain, port)
  #   img.image          = request.body
  #   img.content_length = request.content_length         
  #   img.content_type   = request.content_type           
  #   img.content_md5    = request.headers['Content-MD5'] 
  #
  # Apache waits for all uploads to arrive before passing the request off to
  # Rails.  It stores them in /tmp somewhere until Rails is done with them.
  # (File is an ActionController::UploadedTempfile, which has the method
  # "original_filename", and inherits from Tempfile, which has the methods
  # "size", "path", "delete", etc. and inherits in turn from File...) 
  #
  # *NOTE*: Cannot actually process the image yet since we don't know what the
  # id is going to be.  That's why you have to wait until the record is saved.
  # See +save_image+ for the rest of the job.
  #
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

  # Call this once the new record is saved and we know the id.  Move, copy or
  # save the original file into the correct place, then initiate resizing and
  # transfers.
  #
  #   img = Image.new(args)
  #   img.image = File.new('photo.jpg')
  #   img.save
  #   img.save_image
  #
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

        # If we successfully received the raw image, spawn process to resize it
        # and transfer it to image server.
        if PRODUCTION && !system("script/process_image #{self.id}&")
          errors.add(:image, 'Something went wrong when spawning process_image...')
          result = false
        end
      end
    end
    return result
  end

  # Return file name of original image.
  def original_image
    sprintf("%s/orig/%d.jpg", self.img_dir, self.id)
  end

  # Return file name of normal-size image.
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

  # Return URL for normal-size image.
  def big_url
    sprintf("%s/640/%d.jpg", IMAGE_DOMAIN, self.id)
  end

  # Return URL for thumbnail image.
  def thumbnail_url
    sprintf("%s/thumb/%d.jpg", IMAGE_DOMAIN, self.id)
  end

################################################################################

protected

  def validate # :nodoc:
    if !self.user && !User.current
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

    if self.copyright_holder.to_s.length > 100
      errors.add(:copyright_holder, :validate_image_copyright_holder_too_long.t)
    end
  end
end
