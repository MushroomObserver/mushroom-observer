# encoding: utf-8
#
#  = Image Model
#
#  Most images are, of course, mushrooms, but mugshots use this class, as well.
#  They are indistinguishable at the moment.
#
#  == Votes
#
#  Voting is kept very simple for now.  More might be done later using RDF.
#  User's can choose one of four levels.  Their vote is stored in a simple
#  text string in +votes+:
#
#    "user_id val user_id val ..."
#
#  The average vote is stored in +vote_cache+.  This is just a floating point
#  between 1.0 and 4.0, with 4.0 being the best quality.  All work with votes
#  is done via a single method, +change_vote+, keeping it nicely encapsulated
#  in case we want to do it "properly" later.
#
#  == Files
#
#  The actual image is stored in several files:
#
#    RAILS_ROOT/public/images/orig/<id>.<ext>  # (original file if not jpeg)
#    RAILS_ROOT/public/images/orig/<id>.jpg
#    RAILS_ROOT/public/images/1280/<id>.jpg
#    RAILS_ROOT/public/images/960/<id>.jpg
#    RAILS_ROOT/public/images/640/<id>.jpg
#    RAILS_ROOT/public/images/320/<id>.jpg
#    RAILS_ROOT/public/images/thumb/<id>.jpg
#
#  They are also transferred to a remote image server with more disk space:
#  (images take up 100 Gb as of Jan 2010)
#
#    IMAGE_DOMAIN/<dir>/<id>.<ext>
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
#  2. Attach the image itself by setting the +image+ attribute, then save the
#     Image record:
#
#       # via HTTP form:
#       image.image = params[:image][:upload]
#
#       # via local file:
#       image.image = File.open('file.jpg')
#
#       # Supply any extra header info you may have.
#       image.content_type = 'image/jpeg'
#       image.md5sum = request.header[...]
#
#       # Validate and save record.
#       image.save
#
#  3. After the record is saved, it knows the ID so it can finally write out
#     the original image:
#
#       RAILS_ROOT/public/images/orig/<id>.<ext>
#
#  4. Now it forks off a tiny shell script that takes care of the rest:
#
#       script/process_image $id $ext
#
#  5. First it fills in all the other size images with a place-holder:
#
#       cd RAILS_ROOT/public/images
#       cp place_holder_<size>.jpg <size>/$id.jpg
#
#  6. Next it resizes the original using ImageMagick:
#
#       jpegresize 160x160 -q 90 --max-size orig/$id.jpg thumb/$id.jpg
#       jpegresize 320x320 -q 80 --max-size orig/$id.jpg 320/$id.jpg
#       jpegresize 640x640 -q 70 --max-size orig/$id.jpg 640/$id.jpg
#       etc.
#
#  7. Lastly it transfers all the images to the image server:
#
#       scp orig/$id.<ext>  IMAGE_DOMAIN/orig/$id.<ext>
#       scp orig/$id.jpg    IMAGE_DOMAIN/orig/$id.jpg
#       scp 1280/$id.jpg    IMAGE_DOMAIN/1280/$id.jpg
#       etc.
#
#     (If any errors occur in +script/process_image+ they get emailed to the
#     webmasters.)
#
#  8. A nightly process runs to check for mistakes and remove any images that
#     have been successfully transferred:
#
#       script/update_images --clean
#
#     Currently it only removes ones over 640, leaving the rest local.
#
#  == Low Level Details
#
#  Apache waits for all uploads to arrive before passing the request off to
#  Rails.  It stores them in /tmp somewhere until Rails is done with them.
#
#  Rails passes anything larger than 1024 or so as an
#  ActionController::UploadedTempfile < TempFile < File, which has the methods
#  "original_filename", "size", "path", "delete", etc.  Small files get loaded
#  into memory immediately as ActionController::UploadedStringIO < StringIO <
#  Data, which also has the methods "original_filename", "size", etc.
#
#  If we ever get an IO stream instead of a TempFile, we write it out to a
#  tempfile ourselves (using File.copy_stream).  This way we can run <tt>file
#  -i</tt> on it to determine the correct content type (the users' browsers,
#  as it turns out, cannot be trusted).  Once we've validated it, we move it
#  into place.
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
#  image_dir::          Where images are stored (default is IMG_DIR).
#  upload_handle::      File or IO handle of upload stream.
#  upload_temp_file::   Path of the tempfile holding the upload until we process it.
#  upload_length::      Length of the upload (if available).
#  upload_type::        Mime type of the upload (if available).
#  upload_md5sum::      MD5 hash of the upload (if available).
#  upload_original_name:: Name of the file on the user's machine (if available).
#
#  == Class Methods
#
#  validate_vote::      Validate a vote value.
#  file_name::          Filename (relative to IMG_DIR) given size and id.
#  url::                Full URL on image server given size and id.
#  all_sizes::          All image sizes from +:thumbnail+ to +:full_size+.
#  all_sizes_in_pixels:: All image sizes as pixels instead of Symbol's.
#  all_extensions::     All image extensions, with "raw" for "other".
#  all_content_types::  All image content_types, with +nil+ for "other".
#
#  == Instance Methods
#
#  unique_format_name:: Marked-up title.
#  unique_text_name::   Plain-text title.
#  observations::       Observations that use this image.
#  thumb_clients::      Observations that use this image as their "thumbnail".
#  has_size?::          Does image have this size?
#  size::               Calculate size of image of given type.
#
#  ==== Filenames
#  original_image::     Path of original image.
#  full_size_image::    Path of full-size jpeg.
#  huge_image::         Path of 1280 image.
#  large_image::        Path of 960 image.
#  medium_image::       Path of 640 image.
#  small_image::        Path of 320 image.
#  thumbnail_image::    Path of thumbnail.
#
#  ==== URLs
#  original_url::       URL of original image.
#  full_size_url::      URL of full-size jpeg.
#  huge_url::           URL of 1280 image.
#  large_url::          URL of 960 image.
#  medium_url::         URL of 640 image.
#  small_url::          URL of 320 image.
#  thumbnail_url::      URL of thumbnail.
#
#  ==== Uploading
#  image=::             Attach an image (via IO stream or File).
#  process_image::      Call this after saving new record to process image.
#  validate_upload::    Perform all the checks we can on the upload.
#
#  ==== Voting
#  all_votes::          Array of valid vote values.
#  validate_vote::      Return valid vote value or +nil+.
#  num_votes::          Number of votes cast for this Image.
#  users_vote::         Get User's vote for this Image.
#  change_vote::        Change a User's vote for this Image.
#
#  ==== Callbacks and Logging
#  update_thumbnails::  Change thumbnails before destroy.
#  log_update::         Log update in assocaited Observation's.
#  log_destroy::        Log destroy in assocaited Observation's.
#
################################################################################

require 'fileutils'

class Image < AbstractModel
  has_and_belongs_to_many :observations
  has_many :thumb_clients, :class_name => "Observation", :foreign_key => "thumb_image_id"
  has_many :image_votes
  belongs_to :user
  belongs_to :license
  belongs_to :reviewer, :class_name => "User", :foreign_key => "reviewer_id"

  before_destroy :update_thumbnails

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

  ##############################################################################
  #
  #  :section: Image File Names
  #
  ##############################################################################

  # Return an Array of all image sizes from +:thumbnail+ to +:full_size+.
  def self.all_sizes
    [:thumbnail, :small, :medium, :large, :huge, :full_size]
  end

  # Return an Array of all image sizes as pixels (Fixnum) instead of Symbol's.
  def self.all_sizes_in_pixels
    [160, 320, 640, 960, 1280, 1e10]
  end

  # Return an Array of all the extensions of all the image types we explicitly
  # support.
  def self.all_extensions
    ['jpg', 'gif', 'png', 'tiff', 'bmp', 'raw']
  end

  # Return an Array of all the extensions of all the image content types we
  # explicitly support.  (These will correspond one-to-one with the values
  # returned by +all_extensions+.)  (Note that the catch-all "raw" is just
  # referred to as +nil+ here, however the actual content type should be stored
  # in the image.  It's just that we haven't seen any other types yet.)
  def self.all_content_types
    ['image/jpeg', 'image/gif', 'image/png', 'image/tiff', 'image/x-ms-bmp', nil]
  end

  def original_extension
    case content_type
    when 'image/jpeg'     ; 'jpg'
    when 'image/gif'      ; 'gif'
    when 'image/png'      ; 'png'
    when 'image/tiff'     ; 'tiff'
    when 'image/x-ms-bmp' ; 'bmp'
    else                  ; 'raw'
    end
  end

  def self.file_name(size, id)
    case size
    when :full_size; "orig/#{id}.jpg"
    when :huge;      "1280/#{id}.jpg"
    when :large;     "960/#{id}.jpg"
    when :medium;    "640/#{id}.jpg"
    when :small;     "320/#{id}.jpg"
    when :thumbnail; "thumb/#{id}.jpg"
    end
  end

  def self.url(size, id)
    "#{IMAGE_DOMAIN}/#{file_name(size, id)}"
  end

  def original_file;  "orig/#{id}.#{original_extension}"; end
  def full_size_file; "orig/#{id}.jpg";  end
  def huge_file;      "1280/#{id}.jpg";  end
  def large_file;     "960/#{id}.jpg";   end
  def medium_file;    "640/#{id}.jpg";   end
  def small_file;     "320/#{id}.jpg";   end
  def thumbnail_file; "thumb/#{id}.jpg"; end

  def original_image;  "#{image_dir}/#{original_file}";  end
  def full_size_image; "#{image_dir}/#{full_size_file}"; end
  def huge_image;      "#{image_dir}/#{huge_file}";      end
  def large_image;     "#{image_dir}/#{large_file}";     end
  def medium_image;    "#{image_dir}/#{medium_file}";    end
  def small_image;     "#{image_dir}/#{small_file}";     end
  def thumbnail_image; "#{image_dir}/#{thumbnail_file}"; end

  def original_url;  "#{IMAGE_DOMAIN}/#{original_file}";  end
  def full_size_url; "#{IMAGE_DOMAIN}/#{full_size_file}"; end
  def huge_url;      "#{IMAGE_DOMAIN}/#{huge_file}";      end
  def large_url;     "#{IMAGE_DOMAIN}/#{large_file}";     end
  def medium_url;    "#{IMAGE_DOMAIN}/#{medium_file}";    end
  def small_url;     "#{IMAGE_DOMAIN}/#{small_file}";     end
  def thumbnail_url; "#{IMAGE_DOMAIN}/#{thumbnail_file}"; end

  def has_size?(size)
    max = width.to_i > height.to_i ? width.to_i : height.to_i
    case size.to_s
    when 'thumbnail' ; true
    when 'small'     ; max > 160
    when 'medium'    ; max > 320
    when 'large'     ; max > 640
    when 'huge'      ; max > 960
    when 'full_size' ; max > 1280
    when 'original'  ; true
    else             ; false
    end
  end

  # Calculate the approximate dimensions of the image of the given size.
  def size(size)
    w = width
    h = height
    if width && height
      d = w > h ? w : h
      max = case size.to_s
      when 'thumbnail' ; 160
      when 'small'     ; 320
      when 'medium'    ; 640
      when 'large'     ; 960
      when 'huge'      ; 1280
      when 'full_size', 'original' ; 1e10
      end
      if max < d
        w = w * max / d
        h = h * max / d
      end
    end
    return [w, h]
  end

  ##############################################################################
  #
  #  :section: Image Upload
  #
  #  This is the general public interface:
  #
  #    img = Image.new(args)              # Initialize record.
  #    img.image = File.new('photo.jpg')  # Attach upload.
  #    img.upload_length = ...            # Supply extra header info.
  #    img.upload_md5sum = ...
  #    img.validate_upload                # Validate it.
  #    img.save                           # Create record (to get id).
  #    img.process_image                  # Resize and transfer images.
  #
  ##############################################################################

  # Directory images are stored under.  (Default is +IMG_DIR+.)
  attr_accessor :image_dir
  def image_dir
    @image_dir || IMG_DIR
  end

  # Upload file handle.
  attr_accessor :upload_handle

  # Original name of the file on the user's machine (if available).
  attr_accessor :upload_original_name

  # Name of the temp file it is stored in while processing it.
  attr_accessor :upload_temp_file

  # Length of the file.
  attr_accessor :upload_length

  # Mime type, e.g. "image/jpeg" or "image/x-ms-bmp".
  attr_accessor :upload_type

  # MD5 sum (if available).
  attr_accessor :upload_md5sum

  # Initialize the upload process.  Pass in the value of the file upload filed
  # from the CGI +params+ struct, or any other I/O stream.  You will have the
  # opportunity to provide extra information, such as the original file name,
  # MD5 sum, etc. afterwards before it actually processes the image.
  def image=(file)
    self.upload_handle = file

    case file
      # Image is already stored in a local temp file.  This is how Rails passes
      # large files from Apache.
      when Tempfile
        @file = file
        self.upload_temp_file = file.path
        self.upload_length = file.size
        self.upload_type   = file.content_type if file.respond_to?(:content_type)
        self.upload_md5sum = file.md5sum       if file.respond_to?(:md5sum)
        self.upload_original_name = file.original_filename.to_s.force_encoding('utf-8') \
          if file.respond_to?(:original_filename)

      # Image is given as an input stream.  We need to save it to a temp file
      # before we can do anything useful with it.
      when IO, StringIO
        @file = nil
        self.upload_temp_file = nil
        self.upload_length = file.content_length.chomp if file.respond_to?(:content_length)
        self.upload_length = file.size           if file.respond_to?(:size)
        self.upload_type   = file.content_type   if file.respond_to?(:content_type)
        self.upload_md5sum = file.md5sum         if file.respond_to?(:md5sum)
        self.upload_original_name = file.original_filename.to_s.force_encoding('utf-8') \
          if file.respond_to?(:original_filename)
    end
  end

  # Perform what checks we can on the prospective upload before actually
  # processing it.  Any errors are added to the :image field.
  def validate_upload
    validate_image_length
    validate_image_type
    validate_image_md5sum
    validate_image_name
  end

  # Check to make sure the image isn't too egregiously large.  (Large images
  # can cause ImageMagick to bring the system to its knees.)  Returns true if
  # okay, otherwise adds an error to the :image field.
  def validate_image_length
    if upload_length || save_to_temp_file
      if upload_length > IMAGE_UPLOAD_MAX_SIZE
        errors.add(:image, :validate_image_file_too_big.t(:size => upload_length,
                   :max => IMAGE_UPLOAD_MAX_SIZE.to_s.sub(/\d{6}$/, 'Mb')))
        result = false
      else
        result = true
      end
    end
    return result
  end

  # Check image type to make sure we were given a valid image.  Returns true
  # if okay, otherwise adds an error to the :image field.
  def validate_image_type
    if save_to_temp_file
      # Override whatever user gave us with result of "file --mime".
      type = File.read("| /usr/bin/file --mime #{upload_temp_file}").chomp.split[1]
      if type
        type.sub!(/;$/, '')
        self.upload_type = type
      end
      if upload_type.match(/^image\//)
        result = true
      else
        errors.add(:image, :validate_image_wrong_type.t(:type => upload_type))
        result = false
      end
    end
    self.content_type = upload_type
    return result
  end

  # Check to make sure the MD5 sum is correct (if available).  Returns true
  # unless the test fails, in which case it adds an error to the :image field.
  def validate_image_md5sum
    result = true
    if upload_md5sum and save_to_temp_file
      if (sum = File.read("| /usr/bin/md5sum #{upload_temp_file}")) &&
         (sum.split.first == content_md5)
        result = true
      else
        errors.add(:image, :validate_image_md5_mismatch.
          t(:actual => sum.split.first, :expect => upload_md5sum))
        result = false
      end
    end
    return result
  end

  # Check if we received the name of the original file on the users's computer.
  # Strip out any directories, or drive letters (just in case, don't think this
  # ever actually happens).  Provide default name if not provided.
  def validate_image_name
    name = self.upload_original_name.to_s
    name.sub!(/^[a-zA-Z]:/, '')
    name.sub!(/^.*[\/\\]/, '')
    # name = '(uploaded at %s)' % Time.now.web_time if name.empty?
    name.truncate_binary_length!(120) if name.binary_length > 120
    self.original_name = name
  end

  # Save upload to temp file if haven't already done so.  Any errors are added
  # to the :image field.  Returns true if the file is successfully saved.
  def save_to_temp_file
    result = true
    if !upload_temp_file

      # Image is supplied in a input stream.  This can happen in a variety of
      # cases, including during testing, and also when the image comes in as
      # the body of a request.
      if upload_handle.is_a?(IO) or
         upload_handle.is_a?(StringIO)
        begin
          @file = Tempfile.new('image_upload') # Using an instance variable so the temp file last as long as the reference to the path.
          FileUtils.copy_stream(upload_handle, @file)
          self.upload_temp_file = @file.path
          self.upload_length = @file.size
          result = true
        rescue => e
          errors.add(:image, e.to_s)
          result = false
        end

      # It should never reach here.
      else
        errors.add(:image, "Unexpected error: did not receive a valid upload " +
                           "stream from the webserver (we got an instance of " +
                           "#{upload_handle.class.name}).  Please try again.")
        result = false
      end
    end
    return result
  end

  # Process image now that we're sure everything is okay.  This should only
  # be called after the image has been validated and the record saved.  (We
  # need to have an ID at this point.)  Adds any errors to the :image field
  # and returns false.
  def process_image
    result = true
    if new_record?
      errors.add(:image, "Called process_image before saving image record.")
      result = false
    elsif save_to_temp_file
      ext = original_extension
      set_image_size(upload_temp_file) if ext == 'jpg'
      set = width.nil? ? 'set' : ''
      if !move_original
        result = false
      elsif PRODUCTION && !system("script/process_image #{id} #{ext} #{set}&")
        # Spawn process to resize and transfer images to image server.
        errors.add(:image, :runtime_image_process_failed.t(:id => id))
        result = false
      end
    end
    return result
  end

  # Move temp file into its final position.  Adds any errors to the :image
  # field and returns false.
  def move_original
    raise(SystemCallError, "Don't move my test images!!") if TESTING
    if !File.rename(upload_temp_file, original_image)
      raise(SystemCallError, "Try again.")
    end
    FileUtils.chmod(0644, original_image)
    return true
  rescue SystemCallError
    if !system('cp', upload_temp_file, original_image)
      raise(:runtime_image_move_failed.t(:id => id))
    end
    return true
  rescue SystemCallError
    errors.add(:image, :runtime_image_move_failed.t(:id => id))
    return false
  end

  # Get image size from JPEG header and set the corresponding record fields.
  # Saves the record.
  def set_image_size(file=full_size_image)
    script = "#{RAILS_ROOT}/script/jpegsize"
    w, h = File.read("| #{script} #{file}").chomp.split
    if w.to_s.match(/^\d+$/)
      self.width  = w.to_i
      self.height = h.to_i
      self.save_without_our_callbacks
    end
  end

  ################################################################################
  #
  #  :section: Voting
  #
  ################################################################################

  # Returns an Array of all valid vote values.
  def self.all_votes
    [1, 2, 3, 4]
  end

  # Validate a vote value.  Returns type-cast vote (Fixnum from 1 to 4) if
  # valid, or nil if not.
  def self.validate_vote(value)
    value = value.to_i rescue 0
    value = nil if value < 1 or value > 4
    return value
  end

  # Count number of votes at a given level.  Returns all votes if no +value+.
  def num_votes(value=nil)
    if value
      vote_hash.values.select {|v| v == value.to_i}.length
    else
      vote_hash.values.length
    end
  end

  # Retrieve the given User's vote for this Image.  Returns a Fixnum from
  # 1 to 4, or nil if the User hasn't voted.
  def users_vote(user=User.current)
    user_id = user.is_a?(User) ? user.id : user.to_i
    vote_hash[user_id]
  end

  # Change a user's vote to the given value.  Pass in either the numerical vote
  # value (from 1 to 4) or nil to delete their vote.  Forces all votes to be
  # integers.  Returns value of new vote.
  def change_vote(user, value=nil, anon=false)
    user_id = user.is_a?(User) ? user.id : user.to_i
    save_changes = !self.changed?

    # Modify image_votes table first.
    vote = image_votes.find_by_user_id(user_id)
    if value = self.class.validate_vote(value)
      if vote
        vote.value = value
        vote.anonymous = anon
        vote.save
      else
        image_votes.create(
          :user_id   => user_id,
          :value     => value,
          :anonymous => !!anon
        )
      end
    elsif vote
      image_votes.delete(vote)
    end

    # Update the cached data in images table next. (The "true" forces rails
    # to reload the association.)
    refresh_vote_cache!

    # Save changes unless there were already pending changes to be saved
    # (meaning the caller is presumably about to save the changes anyway so
    # we don't need to do it twice).  No need to update +modified+ or do any
    # of the other callbacks, either, since this doesn't result in emails,
    # contribution changes, or rss log entries.
    if save_changes
      save_without_our_callbacks
    end

    return value
  end

  # Calculate the average vote given the raw vote data.
  def refresh_vote_cache!
    @vote_hash = nil
    sum = num = 0
    for user, value in vote_hash
      sum += value.to_f
      num += 1
    end
    self.vote_cache = num > 0 ? sum / num : nil
  end

  # Retrieve list of users who have voted as a Hash mapping user ids to
  # numerical vote values (Fixnum).  (Forces all votes to be integers.)
  def vote_hash # :nodoc:
    unless @vote_hash
      @vote_hash = {}
      for vote in self.image_votes
        @vote_hash[vote.user_id.to_i] = vote.value.to_i
      end
    end
    return @vote_hash
  end

  ##############################################################################
  #
  #  :section: Callbacks and Logging
  #
  ##############################################################################

  # Callback that changes Observation's thumbnails when an image is destroyed.
  def update_thumbnails
    for obs in observations
      if obs.thumb_image_id == id
        obs.thumb_image_id = (obs.image_ids - [id]).first
        obs.save
      end
    end
  end

  # Log update in associated Observation's.
  def log_update
    for obs in observations
      obs.log_update_image(self)
    end
  end

  # Log destruction in associated Observation's.
  def log_destroy
    for obs in observations
      obs.log_destroy_image(self)
    end
  end

################################################################################

protected

  def validate # :nodoc:
    if upload_handle
      validate_upload
    end

    # I guess this is kind of serious -- uploading with no one logged in??!
    if !self.user && !User.current
      errors.add(:user, :validate_image_user_missing.t)
    end

    # Try everything in our power to make uploads succeed.  Let the user worry
    # about correcting the date later if need be.
    self.when ||= Time.now
    # if !self.when
    #   errors.add(:when, :validate_image_when_missing.t)
    # end

    # Who cares?
    # id self.content_type.to_s.binary_length > 100
    #   errors.add(:content_type, :validate_image_content_type_too_long.t)
    # end

    # Who cares?
    # if self.copyright_holder.to_s.binary_length > 100
    #   errors.add(:copyright_holder, :validate_image_copyright_holder_too_long.t)
    # end
  end
end
