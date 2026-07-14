# frozen_string_literal: true

class Image
  # Resizes and reorients an uploaded image's files, through ActiveRecord
  # (`image.update`) instead of a raw SQL `UPDATE`, so `after_update_commit`
  # callbacks fire -- runs the steps that used to live in
  # script/process_image and script/rotate_image. This class only produces
  # a completed set of local files -- getting them onto the configured
  # image server(s) and keeping them in sync (script/retransfer_images and
  # script/verify_images' old jobs) is TransferImagesJob's job now, not
  # this class's -- see self.transfer_images.
  #
  # 1. convert original to jpeg if necessary
  # 2. reorient it correctly if necessary
  # 3. set width/height of the original image in the database
  # 4. create the five smaller-sized copies
  #
  # GPS stripping is NOT part of this pipeline -- see self.strip_original_gps,
  # which runs synchronously in the request cycle (Image#process_image),
  # before this class's `process` is ever called. That ordering is what
  # guarantees the original is never exposed with real GPS data still in it.
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

    def initialize(image:, user: nil, ext: nil, set_size: false)
      @image = image
      raise("Image::Processor needs an image.") unless @image

      @user = user || @image.user
      raise("Image::Processor needs a user.") unless @user

      @ext = ext || @image.original_extension
      @id = @image.id
      @set_size = set_size
    end

    def process
      convert_raw_to_jpg if convert_raw_to_jpg_needed?
      auto_orient_if_needed(full_size_filepath)
      update_image_record_width_height_and_transferred if @set_size
      make_file_sizes
      compute_dhash
    end

    def rotate(orientation)
      make_sure_we_have_full_size_locally
      reset_file_orientation
      transform_full_size_file(orientation)
      update_image_record_width_height_and_transferred
      process
    end

    # Fetches the original back from whichever configured server has it,
    # if it isn't already local. Public (not just #rotate's concern
    # anymore) -- Image::Processor::GapDetector calls this too, to
    # re-fetch a source for regenerating a size missing on some server.
    # Tries every server with an "orig" subdir, not just the first --
    # a single unreachable server must not abort the fetch when another
    # configured server has the same file.
    def make_sure_we_have_full_size_locally
      return if File.exist?(full_size_filepath)

      self.class.image_servers.each do |server|
        next unless image_server_has_subdir?(server, "orig")
        break if try_fetch_orig(server) && File.exist?(full_size_filepath)
      end

      return if File.exist?(full_size_filepath)

      # script/rotate_image aborted immediately if it couldn't fetch the
      # original -- without this, callers would instead fail later with
      # a confusing MiniExiftool/MiniMagick "file not found" error.
      raise("Could not fetch #{full_size_filepath} from any image server")
    end

    # Transfers and confirms the given images onto every configured image
    # server. See Verifier for details -- this is the event-driven
    # replacement for the old self.retransfer_images / poll-based
    # self.verify_images (both retired, see #4791).
    def self.transfer_images(image_ids, &log)
      Verifier.new(&log).transfer(Image.where(id: image_ids))
    end

    # Occasional full-listing reconciliation pass. See GapDetector for
    # details -- this is the target design's part 4 (#4791): catches
    # server-side drift on already-transferred images that per-image
    # checks alone can't see once local copies are cleaned up.
    def self.detect_gaps(&log)
      GapDetector.new(&log).run
    end

    # Strips GPS/geotag data from an image's original file synchronously,
    # before the image is exposed anywhere -- this can't wait on the
    # deferred resize/transfer pipeline in #process, which may run much
    # later. Only marks gps_stripped once the strip has actually
    # succeeded, never optimistically. Returns nil on success, or an
    # error message string on failure.
    def self.strip_original_gps(image, ext:)
      path = "#{local_images_path}/orig/#{image.id}.#{ext}"
      return "original image file is missing" unless File.exist?(path)
      return "exiftool failed to strip GPS data" unless
        strip_gps_from_file(path)

      image.update_attribute(:gps_stripped, true)
      nil
    end

    # "GPS:all"/"XMP:Geotag" are group-wildcard deletions, not tags
    # MiniExiftool's typed `[]=`/`save` recognizes (it silently no-ops on
    # any tag name outside ExifTool's known-tag map). Shell out directly,
    # matching what script/process_image already did.
    def self.strip_gps_from_file(file)
      system("exiftool", "-gps:all=", "-xmp:geotag=", "-overwrite_original",
             "-q", file)
    end

    private

    # Hash the just-generated small rendition now, while it is still on
    # local disk. Nothing is kept local (MO.keep_these_image_sizes_local
    # is empty in production) and TransferImagesJob moves the files to the
    # image server and deletes the local copies moments later -- so
    # computing the hash here, in the same synchronous flow that produced
    # the file, removes the upload->hash race entirely: no separate job,
    # no waiting for a rendition that may already be gone. Cheap now that
    # dHash uses the 320px rendition, not the full-size original (#4796).
    # A hashing failure must not fail the whole image -- the resized files
    # are already good and worth transferring -- so log and move on.
    def compute_dhash
      @image.compute_dhash!
    rescue Image::Dhash::Error => e
      Rails.logger.warn("dhash failed for image #{@id}: #{e.message}")
    end

    # copy_file_from_server can raise (e.g. Errno::ENOENT via FileUtils.cp
    # when a "file"-type server doesn't actually have the source, or
    # Rsync.run raising if rsync/ssh is unavailable) -- a raised exception
    # must not abort make_sure_we_have_full_size_locally's loop any more
    # than a returned false does, or a single bad server would prevent
    # ever trying the next one.
    def try_fetch_orig(server)
      copy_file_from_server(server, "orig/#{@id}.jpg")
    rescue StandardError
      false
    end

    # Skip if #rotate already produced this from the current full-size
    # file -- reconverting from the raw original here would silently
    # discard that rotation for any non-jpg upload.
    def convert_raw_to_jpg_needed?
      @ext != "jpg" && !File.exist?(full_size_filepath)
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

    def convert_raw_to_jpg
      pipeline = ImageProcessing::MiniMagick.source(original_filepath).
                 append("-quality", 90).
                 append("-auto-orient").
                 saver(allow_splitting: true).
                 convert("jpg")

      pipeline.call(destination: full_size_filepath)
      salvage_first_layer_if_multilayer
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

    def copy_file_from_server(server, remote_file)
      FileTransfer.copy_file_from_server(server, remote_file)
    end
  end
end
