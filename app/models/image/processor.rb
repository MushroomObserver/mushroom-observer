# frozen_string_literal: true

class Image
  # Resizes, reorients, and transfers an uploaded image's files, and keeps
  # the image server(s) in sync with what's stored locally. Runs the steps
  # that used to live in script/process_image, script/rotate_image, and
  # script/retransfer_images, but through ActiveRecord (`image.update`)
  # instead of a raw SQL `UPDATE`, so `after_update_commit` callbacks fire.
  #
  # 1. convert original to jpeg if necessary
  # 2. strip GPS data from the original if requested
  # 3. reorient it correctly if necessary
  # 4. set width/height of the original image in the database
  # 5. create the five smaller-sized copies
  # 6. copy all files to the configured image server(s)
  # 7. email webmaster if there were any errors
  class Processor
    require "image_processing/mini_magick"
    require "mini_exiftool_vendored"
    require "fastimage"
    require "rsync"
    require "open-uri"

    IMAGE_SUBDIRS = Image::URL::SUBDIRECTORIES.values.freeze

    # Store Exiftool's database in a temporary directory.
    MiniExiftool.pstore_dir = Rails.root.join("tmp").to_s

    # Source, destination sizes and quality settings for each conversion.
    SIZE_CONVERSIONS = [
      ["full_size", "huge", 1280, 93],
      ["huge", "large", 960, 94],
      ["huge", "medium", 640, 95], # medium = half of huge
      ["medium", "small", 320, 95],
      ["small", "thumbnail", 160, 95]
    ].freeze

    # MO.local_image_files/MO.image_sources are worker-suffix-aware lazy
    # methods (config/consts.rb) so parallel test workers get distinct
    # directories. Recompute per call rather than caching at class-load
    # time -- if this class autoloads in a forked test worker before that
    # worker's own TEST_ENV_NUMBER is set, a frozen constant would lock in
    # the wrong (unsuffixed) path for the rest of that worker's process
    # lifetime, colliding with every other worker on the same directory.
    def self.local_images_path
      MO.local_image_files
    end

    # Data (type/path/subdirs) for every configured image server, keyed by
    # server name. Includes :local (the filesystem MO itself runs on).
    # Recomputed per call for the same reason local_images_path is above --
    # see ServerData for the actual construction.
    def self.image_server_data
      ServerData.build(local_images_path, IMAGE_SUBDIRS)
    end

    # Servers we transfer files *to* -- excludes :local, which is where the
    # files already live, not a transfer destination.
    def self.image_servers
      image_server_data.keys - [:local]
    end

    attr_reader :transferred_any, :errors

    def initialize(image:, user: nil, ext: nil, set_size: false,
                   strip_gps: false)
      @image = image
      raise("Image::Processor needs an image.") unless @image

      @user = user || @image.user
      raise("Image::Processor needs a user.") unless @user

      @ext = ext || @image.original_extension
      @id = @image.id
      @set_size = set_size
      @strip_gps = strip_gps
      @transferred_any = false
      @errors = []
    end

    def process
      convert_raw_to_jpg if convert_raw_to_jpg_needed?
      if @strip_gps
        strip_gps_from_file(full_size_filepath)
        # A failed strip means the file may still carry GPS data --
        # stop here rather than transfer it to remote image servers,
        # matching script/process_image's `set -e` abort-on-failure.
        return email_webmaster if @errors.any?
      end
      auto_orient_if_needed(full_size_filepath)
      update_image_record_width_height_and_transferred if @set_size
      make_file_sizes
      transfer_files_to_image_servers
      mark_image_record_transferred_and_touch_obs if transferred_cleanly?
      email_webmaster if @errors.any?
    end

    def rotate(orientation)
      make_sure_we_have_full_size_locally
      reset_file_orientation
      transform_full_size_file(orientation)
      update_image_record_width_height_and_transferred
      process
    end

    def transfer_files_to_image_servers
      return if Rails.env.development?

      self.class.image_servers.each do |server|
        transfer_all_sizes_to_server_subdirectories(server)
      end
    end

    # Mark image as transferred and touch related obs (for caches) if all
    # good. Public (not private) because `self.retransfer_images` below
    # calls this on a `processor` instance it created for another image.
    def mark_image_record_transferred_and_touch_obs
      @image.update(transferred: @transferred_any)
      Observation.joins(:observation_images).
        where(observation_images: { image_id: @id }).touch_all
    end

    def self.retransfer_images
      Image.where(transferred: false).find_each do |image|
        processor = new(image: image)
        next unless processor.locally_processed?

        processor.transfer_files_to_image_servers
        if processor.transferred_any && processor.errors.empty?
          processor.mark_image_record_transferred_and_touch_obs
        end
      end
    end

    # True once every expected local derivative exists -- i.e. #process
    # actually finished (make_file_sizes ran) rather than aborting early
    # (e.g. a failed GPS strip, see #process). This is a safety-net
    # retransfer, not a full #process retry: it must never push a
    # partially-processed image. A missing derivative here means
    # #process never reached make_file_sizes, so the "orig" file may
    # still be untouched/GPS-tainted -- blindly transferring whatever
    # subset of local files DOES exist could leak it via "orig" alone,
    # even though the transfer itself would report success.
    def locally_processed?
      Image::URL::SUBDIRECTORIES.each_key.all? do |size|
        File.exist?(send(:"#{size}_filepath"))
      end
    end

    # Ruby port of script/verify_images: lists local vs remote file sizes
    # per subdir/server, uploads mismatches, and deletes local copies once
    # confirmed transferred everywhere relevant. See Verifier for details.
    def self.verify_images(&log)
      Verifier.new(&log).run
    end

    private

    # Skip if #rotate already produced this from the current full-size
    # file -- reconverting from the raw original here would silently
    # discard that rotation for any non-jpg upload.
    def convert_raw_to_jpg_needed?
      @ext != "jpg" && !File.exist?(full_size_filepath)
    end

    def transferred_cleanly?
      @transferred_any && @errors.empty?
    end

    # Strip GPS data
    # "GPS:all"/"XMP:Geotag" are group-wildcard deletions, not tags
    # MiniExiftool's typed `[]=`/`save` recognizes (it silently no-ops on
    # any tag name outside ExifTool's known-tag map). Shell out directly,
    # matching what script/process_image already did.
    def strip_gps_from_file(file)
      return if system("exiftool", "-gps:all=", "-xmp:geotag=",
                       "-overwrite_original", "-q", file)

      @errors << "Failed to strip GPS data from #{file}"
    end

    def make_sure_we_have_full_size_locally
      return if File.exist?(full_size_filepath)

      self.class.image_servers.each do |server|
        next unless image_server_has_subdir?(server, "orig")

        copy_file_from_server(server, "orig/#{@id}.jpg")
        break
      end

      return if File.exist?(full_size_filepath)

      # script/rotate_image aborted immediately if it couldn't fetch the
      # original -- without this, callers would instead fail later with
      # a confusing MiniExiftool/MiniMagick "file not found" error.
      raise("Could not fetch #{full_size_filepath} from any image server")
    end

    def reset_file_orientation
      working = MiniExiftool.new(full_size_filepath, numerical: true)
      return unless working.orientation.to_i != 1

      # This should reset the orientation to 1 from the original data.
      working.copy_tags_from(full_size_filepath, "all")
      return unless working.orientation.to_i != 1

      working.orientation = 1
      working.save
    end

    def transform_full_size_file(orientation)
      operations = %w[-90 +90 180 -h -v]
      return unless operations.include?(orientation)

      pipeline = ImageProcessing::MiniMagick.source(full_size_filepath)
      pipeline = case orientation
                 when "-90", "+90", "180" then pipeline.rotate(orientation)
                 when "-h" then pipeline.flop
                 when "-v" then pipeline.flip
                 end
      pipeline.call(destination: full_size_filepath)
    end

    # Note this also calls strip_gps_from_file(original_filepath).
    def convert_raw_to_jpg
      pipeline = ImageProcessing::MiniMagick.source(original_filepath).
                 append("-quality", 90).
                 append("-auto-orient").
                 saver(allow_splitting: true).
                 convert("jpg")

      pipeline.call(destination: full_size_filepath)
      salvage_first_layer_if_multilayer

      # Strip GPS out of header of original_file if hiding coordinates.
      strip_gps_from_file(original_filepath) if @strip_gps
    end

    # If there were multiple layers, ImageMagick saves them as 1234-N.jpg.
    # Take the largest one (matching script/process_image's
    # `ls -rS ... | tail -1`), and delete the rest.
    def salvage_first_layer_if_multilayer
      return if File.exist?(full_size_filepath)

      layers = Dir.glob("#{self.class.local_images_path}/orig/#{@id}-*.jpg")
      biggest_layer = layers.max_by { |layer| File.size(layer) }
      return unless biggest_layer && File.exist?(biggest_layer)

      FileUtils.cp(biggest_layer, full_size_filepath)
      layers.each { |layer| File.delete(layer) }
    end

    def auto_orient_if_needed(filepath)
      file_to_orient = MiniMagick::Image.open(filepath)
      original_orientation = file_to_orient["%[orientation]"]
      file_to_orient.auto_orient
      new_orientation = file_to_orient["%[orientation]"]

      file_to_orient.write(filepath) if original_orientation != new_orientation
    end

    # This also sets transferred to false to save db writes.
    # Needed in rotate, and later overwritten in process.
    def update_image_record_width_height_and_transferred
      width, height = FastImage.size(full_size_filepath)
      @image.update(width: width, height: height, transferred: false)
    end

    def make_file_sizes
      SIZE_CONVERSIONS.each do |source, destination, size, quality|
        convert_source_to_destination(source, destination, size, quality)
      end
    end

    def convert_source_to_destination(source, destination, size, quality = 95)
      source_filepath = send(:"#{source}_filepath")
      destination_filepath = send(:"#{destination}_filepath")
      pipeline = ImageProcessing::MiniMagick.source(source_filepath).
                 append("-thumbnail", "#{size}x#{size}>").
                 append("-quality", quality).
                 convert("jpg")

      pipeline.call(destination: destination_filepath)
    end

    def transfer_all_sizes_to_server_subdirectories(server)
      subdirs = self.class.image_server_data[server][:subdirs]
      IMAGE_SUBDIRS.each do |subdir|
        next unless subdirs.include?(subdir)

        copy_file_to_server(server, "#{subdir}/#{@id}.jpg")
      end
      if @ext != "jpg" && subdirs.include?("orig")
        copy_file_to_server(server, "orig/#{@id}.#{@ext}")
      end
      @transferred_any = true
    end

    # Email webmaster if there were any errors
    def email_webmaster
      message = WebmasterMailer.prepend_user(@user, @errors.join("\n"))
      WebmasterMailer.build(
        sender_email: @user.email,
        subject: "[MO] process_image",
        message: message
      ).deliver_later
    end

    def image_server_has_subdir?(server, subdir)
      self.class.image_server_data[server][:subdirs].include?(subdir)
    end

    # Original file location
    def original_filepath
      "#{self.class.local_images_path}/orig/#{@id}.#{@ext}"
    end

    # full_size, huge, large, medium, small, thumbnail
    Image::URL::SUBDIRECTORIES.each do |size, subdir|
      define_method(:"#{size}_filepath") do
        "#{self.class.local_images_path}/#{subdir}/#{@id}.jpg"
      end
    end

    ############################################################

    def copy_file_to_server(server, local_file, remote_file = local_file)
      success = FileTransfer.copy_file_to_server(server, local_file,
                                                 remote_file)
      @errors << "Failed to transfer #{local_file} to #{server}" unless success
    end

    def copy_file_from_server(server, remote_file)
      FileTransfer.copy_file_from_server(server, remote_file)
    end
  end
end
