# frozen_string_literal: true

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
#    Rails.root/public/images/orig/<id>.<ext>  # (original file if not jpeg)
#    Rails.root/public/images/orig/<id>.jpg
#    Rails.root/public/images/1280/<id>.jpg
#    Rails.root/public/images/960/<id>.jpg
#    Rails.root/public/images/640/<id>.jpg
#    Rails.root/public/images/320/<id>.jpg
#    Rails.root/public/images/thumb/<id>.jpg
#
#  They are also transferred to a remote image server with more disk space:
#  (images take up 100 Gb as of Jan 2010)
#
#    http://<image_server>/<dir>/<id>.<ext>
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
#         :created_at => Time.now,
#         :user       => @user,
#         :when       => observation.when,
#         :notes      => 'close-up of stipe'
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
#       image.upload_md5sum = request.header[...]
#
#       # Validate and save record.
#       image.save
#
#  3. After the record is saved, it knows the ID so it can finally write out
#     the original image:
#
#       ::Rails.root.to_s/public/images/orig/<id>.<ext>
#
#  4. Now it forks off a tiny shell script that takes care of the rest:
#
#       script/process_image $id $ext
#
#  5. First it fills in all the other size images with a place-holder:
#
#       cd ::Rails.root.to_s/public/images
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
#       scp orig/$id.<ext>  <user>@<image_server>/orig/$id.<ext>
#       scp orig/$id.jpg    <user>@<image_server>/orig/$id.jpg
#       scp 1280/$id.jpg    <user>@<image_server>/1280/$id.jpg
#       etc.
#
#     (If any errors occur in +script/process_image+ they get emailed to the
#     webmasters.)
#
#  8. If all is successful, it sets the +transferred+ bit in the db record.
#     Until this bit is set, MO knows to serve the image off of the web server
#     instead, however inefficient this may be.
#
#  9. A regular process (every 5 minutes?) tries to re-transfer any images
#     whose transfer failed.  Bailing at the first sign of trouble.
#
#  10. A nightly process runs to check for mistakes and remove any images that
#     have been successfully transferred:
#
#       script/update_images --clean
#
#     Currently it only removes ones over 320, leaving the rest local.  Note
#     that images remain on the web server until this verification process
#     happens.
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
#  created_at::         Date/time it was first created.
#  updated_at::         Date/time it was last updated.
#  user::               User that created it.
#  when::               Date image was taken.
#  notes::              Arbitrary notes (string of any length).
#  content_type::       MIME type of original image (the rest are 'image/jpeg').
#  copyright_holder::   Copyright holder (defaults to legal name of owner).
#  license::            License.
#  license_history::    Accounting history of any license changes
#                       (started using April 2012).
#  quality::            Quality (e.g., :low, :medium, :high).
#  num_views::          Number of times normal-size image has been viewed.
#  last_view::          Last time normal-size image was viewed.
#  transferred::        Has this image been successfully transferred to the
#                       image server yet?
#
#  ==== Temporary attributes
#
#  image_dir::          Where images are stored (default: MO.local_image_files).
#  upload_handle::      File or IO handle of upload stream.
#  upload_temp_file::   Path of tempfile holding the upload until we process it.
#  upload_length::      Length of the upload (if available).
#  upload_type::        Mime type of the upload (if available).
#  upload_md5sum::      MD5 hash of the upload (if available).
#  upload_original_name:: Name of the file on the user's machine (if available).
#
#  == Class Constants
#
#  ALL_SIZES_INDEX::    Hash of image sizes and their pixel dimensions.
#  ALL_SIZES::          All image sizes from +:thumbnail+ to +:full_size+.
#  ALL_SIZES_IN_PIXELS:: All image sizes as pixels instead of Symbols.
#  ALL_EXTENSIONS::     All image extensions, with "raw" for "other".
#  ALL_CONTENT_TYPES::  All image content_types, with +nil+ for "other".
#
#  == Class Methods
#
#  validate_vote::      Validate a vote value.
#  full_filepath::      Full filepath (relative to MO.local_image_files)
#                       given size and id.
#  url::                relative URL on image server given size and id.
#  licenses_for_user_by_type:
#                       Expensive query of image licenses the user has used.
#  process_license_changes_for_user: Change licenses from one type to another.
#
#  == Instance Methods
#
#  unique_format_name:: Marked-up title.
#  unique_text_name::   Plain-text title.
#  observations::       Observations that use this image.
#  thumb_observations:: Observations that use this as their "thumbnail".
#  glossary_terms::     GlossaryTerms that use this image.
#  thumb_glossary_terms:: GlossaryTerms that use this as their "thumbnail".
#  has_size?::          Does image have this size?
#  size::               Calculate size of image of given type.
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
#  transform::          Rotate and flip image after it's already been uploaded.
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
#  track_copyright_changes:: Log changes in copyright info.
#  log_update::         Log update in associated observations, etc.
#  log_destroy::        Log destroy in associated observations, etc.
#  log_create_for::     Log adding new image to associated observtion, etc.
#  log_reuse_for::      Log adding existing image to associated observtion, etc.
#  log_remove_from::    Log removing image from associated observtion, etc.
#
################################################################################
#
class Image < AbstractModel # rubocop:disable Metrics/ClassLength
  require("mimemagic")
  require("fastimage")

  include Scopes

  has_many :glossary_term_images, dependent: :destroy
  has_many :glossary_terms, through: :glossary_term_images
  has_many :thumb_glossary_terms, class_name: "GlossaryTerm",
                                  foreign_key: "thumb_image_id",
                                  inverse_of: :thumb_image

  has_many :observation_images, dependent: :destroy
  has_many :observations, through: :observation_images
  has_many :thumb_observations, class_name: "Observation",
                                foreign_key: "thumb_image_id",
                                inverse_of: :thumb_image

  has_many :project_images, dependent: :destroy
  has_many :projects, through: :project_images

  has_many :visual_group_images, dependent: :destroy
  has_many :visual_groups, through: :visual_group_images

  has_many :image_votes, dependent: :destroy

  has_many :profile_users, class_name: "User"

  belongs_to :user
  belongs_to :license

  has_many :copyright_changes, as: :target,
                               dependent: :destroy,
                               inverse_of: :target

  after_update :track_copyright_changes
  before_destroy :update_thumbnails

  # Array of all observations, users and glossary terms using this image.
  def all_subjects
    observations + profile_users + glossary_terms
  end

  # Is image used by an object other than obj
  def other_subjects?(obj)
    (all_subjects - [obj]).present?
  end

  # Create plain-text title for image from observations, appending image id to
  # guarantee uniqueness.  Examples:
  #
  #   "Image #1"
  #   "Amanita lanei (Murr.) Sacc. & Trott. (2)"
  #   "Agaricus campestris L. & Agaricus californicus Peck. (3)"
  #
  def unique_text_name
    title = all_subjects.map(&:text_name).uniq.sort.join(" & ")
    if title.blank?
      :image.l + " ##{id || "?"}"
    else
      title + " (#{id || "?"})"
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
    title = all_subjects.map(&:format_name).uniq.sort.join(" & ")
    if title.blank?
      :image.l + " ##{id || "?"}"
    else
      title + " (#{id || "?"})"
    end
  end

  # How this image is refered to in the rss logs.
  def log_name
    "##{id || was || "?"}"
  end

  ##############################################################################
  #
  #  :section: Image File Names
  #
  ##############################################################################

  # Return a hash of all image sizes as pixels (Integer) indexed by Symbol.
  ALL_SIZES_INDEX = {
    thumbnail: 160,
    small: 320,
    medium: 640,
    large: 960,
    huge: 1280,
    full_size: 1e10
  }.freeze

  # Return an Array of all image sizes from +:thumbnail+ to +:full_size+.
  ALL_SIZES = ALL_SIZES_INDEX.keys.freeze

  # Return an Array of all image sizes as pixels (Integer) instead of Symbol's.
  ALL_SIZES_IN_PIXELS = ALL_SIZES_INDEX.values.freeze

  # Return an Array of all the extensions of all the image types we explicitly
  # support.
  ALL_EXTENSIONS = %w[jpg gif png tiff bmp raw].freeze

  # Return an Array of all the extensions of all the image content types we
  # explicitly support.  (These will correspond one-to-one with the values
  # returned by +all_extensions+.)  (Note that the catch-all "raw" is just
  # referred to as +nil+ here, however the actual content type should be stored
  # in the image.  It's just that we haven't seen any other types yet.)
  ALL_CONTENT_TYPES = ["image/jpeg", "image/gif", "image/png", "image/tiff",
                       "image/x-ms-bmp", "image/bmp", nil].freeze

  SEARCHABLE_FIELDS = [
    :original_name, :copyright_holder, :notes
  ].freeze

  def image_url(size)
    Image::URL.new(
      size: size,
      id: id,
      transferred: transferred,
      extension: extension(size)
    )
  end

  def self.image_url(size, id, args = {})
    Image::URL.new(
      size: size,
      id: id,
      transferred: args.fetch(:transferred, true),
      extension: args.fetch(:extension, "jpg")
    )
  end

  def url(size)
    image_url(size).url
  end

  def self.url(size, id, args = {})
    image_url(size, id, args).url
  end

  def all_urls
    hash = {}
    ALL_SIZES.each do |size|
      hash[size] = image_url(size).url
    end
    hash
  end

  def self.all_urls(id, args = {})
    hash = {}
    ALL_SIZES.each do |size|
      hash[size] = image_url(size, id, args).url
    end
    hash
  end

  def full_filepath(size)
    image_url(size).full_filepath(MO.local_image_files)
  end

  # Defines methods for each size. e.g. `{size}_url`
  # full_size_url, huge_url, large_url, medium_url, small_url, thumbnail_url
  ALL_SIZES.each do |size|
    define_method(:"#{size}_url") do
      url(size)
    end
  end

  def original_url
    url(:original)
  end

  def original_extension
    case content_type
    when "image/jpeg" then "jpg"
    when "image/gif" then "gif"
    when "image/png" then "png"
    when "image/tiff" then "tiff"
    when "image/bmp", "image/x-ms-bmp" then "bmp"
    else; "raw"
    end
  end

  def extension(size)
    size == :original ? original_extension : "jpg"
  end

  # Calculate the approximate dimensions of the image of the given size.
  def size(size)
    w = width
    h = height
    if width && height
      d = [w, h].max
      max = case size.to_s
            when "thumbnail" then 160
            when "small" then 320
            when "medium" then 640
            when "large" then 960
            when "huge" then 1280
            else; 1e10
            end
      if max < d
        w = w * max / d
        h = h * max / d
      end
    end
    [w, h]
  end

  def self.cached_original_file_path(id)
    "#{MO.local_original_image_cache_path}/#{id}.jpg"
  end

  def self.cached_original_url(id)
    "#{MO.local_original_image_cache_url}/#{id}.jpg"
  end

  def cached_original_file_path
    self.class.cached_original_file_path(id)
  end

  def cached_original_url
    self.class.cached_original_url(id)
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

  # Directory images are stored under.  (Default is +MO.local_image_files+.)
  attr_accessor :image_dir

  def image_dir
    @image_dir || MO.local_image_files
  end

  # Upload file handle.
  attr_accessor :upload_handle

  # Original name of the file on the user's machine (if available).
  attr_accessor :upload_original_name

  # Name of the temp file it is stored in while processing it.
  attr_accessor :upload_temp_file

  # Length of the file.
  attr_accessor :upload_length

  # Mime type, e.g. "image/jpeg".
  attr_accessor :upload_type

  # MD5 sum (if available).
  attr_accessor :upload_md5sum

  # Proc to call after #process_image has been called.
  attr_accessor :clean_up_proc

  def clean_up
    clean_up_proc.try(&:call)
  end

  # Initialize the upload process.  Pass in the value of the file upload filed
  # from the CGI +params+ struct, or any other I/O stream.  You will have the
  # opportunity to provide extra information, such as the original file name,
  # MD5 sum, etc. afterwards before it actually processes the image.
  def image=(file)
    self.upload_handle = file
    if local_file?(file)
      init_image_from_local_file(file)
    elsif input_stream?(file)
      init_image_from_stream(file)
    else
      raise("Unexpected image upload class, #{file.class.name}.")
    end
  end

  # Is image already stored in a local temp file?
  def local_file?(file)
    file.is_a?(Tempfile) ||
      file.is_a?(ActionDispatch::Http::UploadedFile) ||
      file.is_a?(Rack::Test::UploadedFile)
  end

  # Is image an input stream?
  def input_stream?(file)
    file.is_a?(IO) ||
      file.is_a?(StringIO) ||
      defined?(Unicorn) && file.is_a?(Unicorn::TeeInput)
  end

  def init_image_from_local_file(file)
    @file = file
    if file.path.blank?
      Rails.logger.info { "File: #{file}" }
      raise("Weird: file.path is blank!")
    end

    self.upload_temp_file = file.path
    self.upload_length    = file.size
    add_extra_attributes_from_file(file)
  end

  # Image is given as an input stream. We need to save it to a temp file
  # before we can do anything useful with it.
  def init_image_from_stream(file)
    @file = nil
    self.upload_temp_file = nil
    if file.respond_to?(:content_length)
      self.upload_length = file.content_length.chomp
    end
    self.upload_length = file.size if file.respond_to?(:size)
    add_extra_attributes_from_file(file)
  end

  def add_extra_attributes_from_file(file)
    self.upload_type     = file.content_type if file.respond_to?(:content_type)
    self.upload_md5sum   = file.md5sum       if file.respond_to?(:md5sum)
    return unless file.respond_to?(:original_filename)

    self.upload_original_name = file.original_filename.to_s.
                                force_encoding("utf-8")
  end

  def upload_from_url(url)
    upload = API2::UploadFromURL.new(url)
    self.image         = upload.content
    self.upload_length = upload.content_length
    self.upload_type   = upload.content_type
    self.upload_md5sum = upload.content_md5
    self.clean_up_proc = -> { upload.clean_up }
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
      if upload_length > MO.image_upload_max_size
        errors.add(:image,
                   :validate_image_file_too_big.t(
                     size: upload_length,
                     max: MO.image_upload_max_size.to_s.sub(/\d{6}$/, "Mb")
                   ))
        result = false
      else
        result = true
      end
    end
    result
  end

  # Check image type to make sure we were given a valid image.  Returns true
  # if okay, otherwise adds an error to the :image field.
  def validate_image_type
    if save_to_temp_file
      # Override whatever user gave us with result of "file --mime".
      self.upload_type =
        MimeMagic.by_magic(File.open(upload_temp_file)).try(&:type)
      if upload_type&.start_with?("image")
        result = true
      else
        file = upload_original_name.to_s
        file = "?" if file.blank?
        errors.add(:image,
                   :validate_image_wrong_type.t(type: upload_type, file: file))
        result = false
      end
    end
    self.content_type = upload_type
    result
  end

  # Check to make sure the MD5 sum is correct (if available).  Returns true
  # unless the test fails, in which case it adds an error to the :image field.
  def validate_image_md5sum
    result = true
    if upload_md5sum.present? && save_to_temp_file
      sum = File.open(upload_temp_file) do |f|
        Digest::MD5.hexdigest(f.read)
      end
      if sum == upload_md5sum
        result = true
      else
        errors.add(:image, :validate_image_md5_mismatch.
          t(actual: sum.split.first, expect: upload_md5sum))
        result = false
      end
    end
    result
  end

  # Check if we received the name of the original file on the users's computer.
  # Strip out any directories, or drive letters (just in case, don't think this
  # ever actually happens).  Provide default name if not provided.
  def validate_image_name
    name = upload_original_name.to_s
    name = name.sub(/^[a-zA-Z]:/, "")
    name = name.sub(%r{^.*[/\\]}, "")
    # name = '(uploaded at %s)' % Time.now.web_time if name.empty?
    name = name.truncate(120)
    return unless name.present? && user&.keep_filenames != "toss"

    self.original_name = name
  end

  # Save upload to temp file if haven't already done so.  Any errors are added
  # to the :image field.  Returns true if the file is successfully saved.
  def save_to_temp_file
    result = true
    if upload_temp_file.blank?

      # Image is supplied in a input stream.  This can happen in a variety of
      # cases, including during testing, and also when the image comes in as
      # the body of a request.
      if upload_handle.is_a?(IO) || upload_handle.is_a?(StringIO) ||
         defined?(Unicorn) && upload_handle.is_a?(Unicorn::TeeInput)
        begin
          # Using an instance variable so the temp file lasts as long as
          # the reference to the path.
          @file = Tempfile.new("image_upload")
          File.open(@file, "wb") do |write_handle|
            loop do
              str = upload_handle.read(16_384)
              break if str.to_s.empty?

              write_handle.write(str)
            end
          end
          # This seems to have problems with character encoding(?)
          # FileUtils.copy_stream(upload_handle, @file)
          self.upload_temp_file = @file.path
          self.upload_length = @file.size
          result = true
        rescue StandardError => e
          errors.add(:image,
                     "Unexpected error while copying attached file " \
                     "to temp file. Error class #{e.class}: #{e}")
          result = false
        end

      # It should never reach here.
      else
        errors.add(:image, "Unexpected error: did not receive a valid upload " \
                           "stream from the webserver (we got an instance of " \
                           "#{upload_handle.class.name}). Send this to the " \
                           "webmaster, please.  Backtrace: #{caller[0..20]}...")
        result = false
      end
    end
    result
  end

  # Process image now that we're sure everything is okay.  This should only
  # be called after the image has been validated and the record saved.  (We
  # need to have an ID at this point.)  Adds any errors to the :image field
  # and returns false.
  def process_image(strip: false)
    result = true
    if new_record?
      errors.add(:image, "Called process_image before saving image record.")
      result = false
    elsif save_to_temp_file
      ext = original_extension
      set_image_size(upload_temp_file) if ext == "jpg"
      set = width.nil? ? "1" : "0"
      update_attribute(:gps_stripped, true) if strip
      strip = strip ? "1" : "0"
      if move_original
        cmd = MO.process_image_command.
              gsub("<id>", id.to_s).
              gsub("<ext>", ext).
              gsub("<set>", set).
              gsub("<strip>", strip)
        if !Rails.env.test? && !system(cmd)
          errors.add(:image, :runtime_image_process_failed.t(id: id))
          result = false
        end
      else
        result = false
      end
    end
    result
  end

  # Move temp file into its final position.  Adds any errors to the :image
  # field and returns false.
  def move_original
    original_image = full_filepath(:original)
    unless File.rename(upload_temp_file, original_image)
      raise(SystemCallError.new("Try again."))
    end

    FileUtils.chmod(0o644, original_image)
    true
  rescue SystemCallError
    # Use Kernel.system to allow stubbing in tests
    unless Kernel.system("cp", upload_temp_file, original_image)
      raise(:runtime_image_move_failed.t(id: id))
    end

    true
  end

  # Get image size from JPEG header and set the corresponding record fields.
  # Saves the record. NOTE: Requires gem("fastimage")
  def set_image_size(file = full_filepath(:full_size))
    w, h = FastImage.size(file)
    return unless /^\d+$/.match?(w.to_s)

    self.width  = w.to_i
    self.height = h.to_i
    save_without_our_callbacks
  end

  # Rotate or flip image.
  def transform(operator)
    case operator
    when :rotate_left then operator = "-90"
    when :rotate_right then operator = "+90"
    when :mirror then operator = "-h"
    else
      raise("Invalid transform operator: #{operator.inspect}")
    end
    system("script/rotate_image #{id} #{operator}&") unless Rails.env.test?
  end

  # Attempt to strip GPS data from original image. Returns error message as
  # string if it fails.
  def strip_gps!
    return nil if gps_stripped

    output, status = Open3.capture2e("script/strip_exif", id.to_s,
                                     transferred ? "1" : "0")
    return output unless status.success?

    update_attribute(:gps_stripped, true)
    nil
  end

  # Get exif data from image by reading the header straight off the file,
  # remotely. Returns nil if it fails. Costly.
  def read_exif_data(flags = [])
    hide_gps = observations.any?(&:gps_hidden)

    if transferred
      cmd = Shellwords.escape("script/exiftool_remote")
      path = Shellwords.escape(original_url)
    else
      cmd  = Shellwords.escape("exiftool")
      path = Shellwords.escape(full_filepath("orig"))
    end
    flags.map { |flag| Shellwords.escape(flag) }
    result, status = Open3.capture2e(cmd, *flags, path)

    data = status.success? ? self.class.parse_exif_data(result, hide_gps) : nil
    [data, status, result]
  end

  # This returns a { lat:, lng:, ... } hash if the image has GPS data in EXIF.
  # Returns nil if it fails. Note that it only reads these fields.
  # Used for edit obs, to allow re-syncing image data to obs.
  def read_exif_geocode
    # flag -n means numerical format, rather than degrees/minutes/seconds.
    flags = %w[-n -GPSLatitude -GPSLongitude -GPSAltitude -filesize
               -DateTimeOriginal]
    data = read_exif_data(flags)[0]
    return nil unless data

    lat = lng = alt = date = file_size = nil
    data.each do |key, val|
      lat = val.to_f.round(4) if key.match?(/latitude/i)
      lng = val.to_f.round(4) if key.match?(/longitude/i)
      alt = val.to_f.round(0) if key.match?(/altitude/i)
      date = val if key.match?(/date/i)
      file_size = val if key.match?(/size/i)
    end
    return nil unless lat && lng

    if date
      date = DateTime.strptime(date, "%Y:%m:%d %H:%M:%S").strftime("%d-%B-%Y")
    end

    file_size = "#{(file_size.to_i / 1024).to_i}kb" if file_size

    { lat:, lng:, alt:, date:, file_name: nil, file_size: }
  end

  GPS_TAGS = /latitude|longitude|gps/i

  def self.parse_exif_data(result, hide_gps)
    result.fix_utf8.split("\n").
      map { |line| line.split(/\s*:\s+/, 2) }.
      select { |_key, val| val != "" && val != "n/a" }.
      reject { |key, _val| hide_gps && key.match(GPS_TAGS) }
  end

  ##############################################################################
  #
  #  :section: Voting
  #
  ##############################################################################

  # Returns an Array of all valid vote values.
  def self.all_votes
    [1, 2, 3, 4]
  end

  # Returns minimum vote.
  def self.minimum_vote
    all_votes.first
  end

  # Returns maximum vote.
  def self.maximum_vote
    all_votes.last
  end

  # Validate a vote value.  Returns type-cast vote (Integer from 1 to 4) if
  # valid, or nil if not.
  def self.validate_vote(value)
    value = begin
              value.to_i
            rescue StandardError
              0
            end
    value = nil if value < 1 || value > 4
    value
  end

  # Count number of votes at a given level.  Returns all votes if no +value+.
  def num_votes(value = nil)
    if value
      vote_hash.values.count { |v| v == value.to_i }
    else
      vote_hash.values.length
    end
  end

  # Retrieve the given User's vote for this Image.  Returns a Integer from
  # 1 to 4, or nil if the User hasn't voted.
  def users_vote(user = User.current)
    user_id = user.is_a?(User) ? user.id : user.to_i
    vote_hash[user_id]
  end

  # Change a user's vote to the given value.  Pass in either the numerical vote
  # value (from 1 to 4) or nil to delete their vote.  Forces all votes to be
  # integers.  Returns value of new vote.
  def change_vote(user, value, anon: false)
    user_id = user.is_a?(User) ? user.id : user.to_i
    save_changes = !changed?

    # Modify image_votes table first.
    vote = image_votes.find_by(user_id: user_id)
    if (value = self.class.validate_vote(value))
      if vote
        vote.value = value
        vote.anonymous = anon
        vote.save
      else
        image_votes.create(
          user_id: user_id,
          value: value,
          anonymous: !!anon
        )
      end
    elsif vote
      image_votes.delete(vote)
    end

    # Update the cached data in images table next.
    refresh_vote_cache!

    # Save changes unless there were already pending changes to be saved
    # (meaning the caller is presumably about to save the changes anyway so
    # we don't need to do it twice).  No need to update +updated_at+ or do any
    # of the other callbacks, either, since this doesn't result in emails,
    # contribution changes, or rss log entries.
    save_without_our_callbacks if save_changes
    # update +updated_at+ for any associated observations, in order to update
    # the cached interactive_image in the matrix_box (contrast with the above)
    observations&.touch_all

    value
  end

  # Calculate the average vote given the raw vote data.
  def refresh_vote_cache!
    @vote_hash = nil
    image_votes.reload
    sum = num = 0
    vote_hash.each_value do |value|
      sum += value.to_f
      num += 1
    end
    self.vote_cache = num.positive? ? sum / num : nil
  end

  # Retrieve list of users who have voted as a Hash mapping user ids to
  # numerical vote values (Integer).  (Forces all votes to be integers.)
  def vote_hash # :nodoc:
    unless @vote_hash
      @vote_hash = {}
      image_votes.each do |vote|
        @vote_hash[vote.user_id.to_i] = vote.value.to_i
      end
    end
    @vote_hash
  end

  def reload(*args)
    @vote_hash = nil
    super
  end

  ##############################################################################
  #
  #  :section: Projects
  #
  ##############################################################################

  def can_edit?(user = User.current)
    Project.can_edit?(self, user)
  end

  ##############################################################################
  #
  #  :section: Callbacks and Logging
  #
  ##############################################################################

  # Callback that changes objects referencing an image that is being destroyed.
  def update_thumbnails
    (thumb_glossary_terms + thumb_observations + profile_users).each do |obj|
      obj.remove_image(self)
    end
  end

  # Log update in associated observations, glossary terms, etc.
  def log_update
    (glossary_terms + observations).each do |object|
      object.log(:log_image_updated, name: log_name, touch: false)
    end
  end

  # Log destruction in associated observations, glossary terms, etc.
  def log_destroy
    (glossary_terms + observations).each do |object|
      object.log(:log_image_destroyed, name: log_name, touch: true)
    end
  end

  # Log adding new image to an associated observation, glossary term, etc.
  def log_create_for(object)
    object.user_log(user, :log_image_created, name: log_name, touch: true)
  end

  # Log adding existing image to an associated observation, glossary term, etc.
  def log_reuse_for(object)
    object.log(:log_image_reused, name: log_name, touch: true)
  end

  # Log removing an image from an associated observation, glossary term, etc.
  def log_remove_from(object)
    object.log(:log_image_removed, name: log_name, touch: false)
  end

  # Create CopyrightChange entry whenever year, name or license changes.
  def track_copyright_changes
    if saved_change_to_when? &&
       saved_change_to_when[0].year != saved_change_to_when[1].year ||
       saved_change_to_license_id? ||
       saved_change_to_copyright_holder?
      old_year       = begin
                         saved_change_to_when[0].year
                       rescue StandardError
                         self.when.year
                       end
      old_name       = begin
                         saved_change_to_copyright_holder[0]
                       rescue StandardError
                         copyright_holder
                       end
      old_license_id = begin
                         saved_change_to_license_id[0]
                       rescue StandardError
                         license_id
                       end
      CopyrightChange.create!(
        user: User.current,
        updated_at: updated_at,
        target: self,
        year: old_year,
        name: old_name,
        license_id: old_license_id
      )
    end
  end

  # Whenever a user changes their name, update all their images.
  def self.update_copyright_holder(old_name, new_name, user)
    data = Image.where(user: user, copyright_holder: old_name).
           pluck(:id, Image[:when].year, :license_id)
    return unless data.any?

    CopyrightChange.insert_all(copyright_change_new_rows(data, old_name, user))

    Image.where(user_id: user.id, copyright_holder: old_name).
      update_all(copyright_holder: new_name)
  end

  private_class_method def self.copyright_change_new_rows(
    data, old_name, user
  )
    data.map do |id, year, lic|
      { "user_id" => user.id,
        "updated_at" => Time.zone.now,
        "target_type" => "Image",
        "target_id" => id,
        "year" => year,
        "name" => old_name,
        "license_id" => lic }
    end
  end

  # Returns a hash that groups all the images of a given copyright holder
  # and license type intoa single row.  This lets you change all Rolf's
  # licenses in one stroke.
  # Inputs:
  #   params[:updates][n][:old_id]      (old license_id)
  #   params[:updates][n][:new_id]      (new license_id)
  #   params[:updates][n][:old_holder]  (old copyright holder)
  #   params[:updates][n][:new_holder]  (new copyright holder)
  # Outputs: @data
  #   @data[n]["copyright_holder"]  Person who actually holds copyright.
  #   @data[n]["license_count"]     Number of images this guy holds with
  #                                 this type of license.
  #   @data[n]["license_id"]        ID of current license.
  #   @data[n]["license_name"]      Name of current license.
  #   @data[n]["licenses"]          Options for select menu.
  #
  #  for testing: initial SQL result
  #  [{"license_count"=>10764, "copyright_holder"=>"Jason Hollinger",
  #    "license_id"=>3},
  #   {"license_count"=>4, "copyright_holder"=>"Alan Cressler",
  #    "license_id"=>3},
  #   {"license_count"=>1, "copyright_holder"=>"Tim Wheeler", "license_id"=>2}]
  #   map(&:attributes) gives you a hash of your selects with their keys

  def self.licenses_for_user_by_type(user)
    display_names = {}
    available_names_and_ids = {}

    License.find_each do |license|
      display_names[license.id] = license.display_name
      available_names_and_ids[license.id] =
        License.available_names_and_ids(license)
    end

    Image.where(user: user).
      select(Arel.star.count.as("license_count"),
             :copyright_holder, :license_id).
      group(:copyright_holder, :license_id).
      map(&:attributes).map do |datum|
      license_id = datum["license_id"].to_i
      datum["license_name"] = display_names[license_id]
      datum["licenses"] = available_names_and_ids[license_id]
      datum.except!("id")
    end
  end

  def self.process_license_changes_for_user(user, updates)
    updates.each_value do |row|
      next unless row_changed?(row)

      images_to_update = Image.where(
        user: user, license: row[:old_id], copyright_holder: row[:old_holder]
      )
      update_licenses_history(user, images_to_update, row[:old_holder],
                              row[:old_id])

      # Update the license info in the images
      images_to_update.update_all(license_id: row[:new_id],
                                  copyright_holder: row[:new_holder])
    end
  end

  private_class_method def self.row_changed?(row)
    row[:old_id] != row[:new_id] ||
    row[:old_holder] != row[:new_holder]
  end

  # Add license change records with a single insert to the db.
  # Otherwise updating would take too long for many (e.g. thousands) of images
  private_class_method def self.update_licenses_history(
    user, images_to_update, old_holder, old_license_id
  )
    CopyrightChange.insert_all(
      images_to_update.map do |image|
        { user_id: user.id,
          updated_at: Time.current,
          target_type: "Image",
          target_id: image.id,
          year: image.when.year,
          name: old_holder,
          license_id: old_license_id }
      end
    )
  end

  def year
    self.when.year
  end

  ##############################################################################

  protected

  validate :check_requirements
  def check_requirements # :nodoc:
    validate_upload if upload_handle && new_record?

    # I guess this is kind of serious -- uploading with no one logged in??!
    errors.add(:user, :validate_image_user_missing.t) if !user && !User.current

    # Try everything in our power to make uploads succeed.  Let the user worry
    # about correcting the date later if need be.
    self.when ||= Time.zone.now

    if content_type.to_s.size > 100
      self.content_type = content_type.to_s.truncate(100)
    end

    return if copyright_holder.to_s.size <= 100

    self.copyright_holder = copyright_holder.to_s.truncate(100)
  end
end
