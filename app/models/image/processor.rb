# frozen_string_literal: true

# Image::Processor. Not to be confused with the ImageProcessing gem's class.
#
# Methods
# `process`
# Resize and transfer uploaded images to the image server(s).
# It is intended to run asynchronously via Active Job.  One of these
# jobs is spwaned for each image uploaded.  It takes these steps:

# 1. convert original to jpeg if necessary
# 2. reorient it correctly if necessary
# 3. set size of original image in database if 'set' flag used
# 4. create the five smaller-sized copies
# 5. copy all files to the image server(s) if in production mode
# 6. email webmaster if there were any errors

# Original script ensures that no other processes are running ImageMagick or
# scp before it runs its own commands.  If another is running, it sleeps a few
# seconds and tries again.
#
# This class could potentially also house `retransfer` and `rotate` methods

class Image
  class Processor
    require "image_processing/mini_magick"
    require "exiftool_vendored"
    require "mini_exiftool"
    require "fastimage"
    require "rsync"
    require "open-uri"

    # Use the vendored version of Exiftool.
    MiniExiftool.command = Exiftool.command
    # Store Exiftool's database in a temporary directory.
    MiniExiftool.pstore_dir = Rails.root.join("tmp").to_s
    # Where the private key is stored for scp.
    PRIVATE_KEY_PATH = Rails.root.join(".ssh/id_rsa").to_s
    # Source, destination sizes and quality settings for each conversion.
    SIZE_CONVERSIONS = [
      ["full_size", "huge", 1280, 93],
      ["huge", "large", 960, 94],
      ["huge", "medium", 640, 95], # medium = half of huge
      ["medium", "small", 320, 95],
      ["small", "thumbnail", 160, 95]
    ].freeze

    def initialize(args = {})
      @image = args[:image]
      raise(:process_image_no_image.t) unless @image

      @user = args[:user]
      raise(:process_image_no_user.t) unless @user

      @ext = args[:ext]
      raise(:process_image_no_ext.t) unless @ext

      @id = @image.id
      @set_size = args[:set_size]
      @strip_gps = args[:strip_gps]

      @transferred_any = 0
      @image_servers = image_servers
      @image_server_data = image_server_data
      @errors = []
    end

    def process
      # for debugging
      # perform_desc = "#{@id}, #{@ext}, #{@set_size}, #{@strip_gps}"
      # log("Starting Image::Processor.process(#{perform_desc})")

      # image.update_attribute(:upload_status, "pending")
      convert_raw_to_jpg if @ext != "jpg"
      strip_gps_from_file(full_size_file) if @strip_gps
      auto_orient_if_needed(full_size_file)
      update_image_record_width_and_height if @set_size
      make_file_sizes
      transfer_files_to_image_servers
      mark_image_record_transferred if @transferred_any
      email_webmaster if @errors.any?

      # for debugging
      # log("Done with Image::Processor.process(#{perform_args})")
    end

    # Strip GPS data
    def strip_gps_from_file(file)
      working = MiniExiftool.new(file)
      working["GPS:all"] = nil
      working["XMP:Geotag"] = nil
      working.save
    end

    # def rotate_image; end

    # def retransfer_image; end

    private

    # Note this also calls strip_gps_from_file(raw_file).
    def convert_raw_to_jpg
      pipeline = ImageProcessing::MiniMagick.source(raw_file).
                 append("-quality", 90).
                 append("-auto-orient").
                 saver(allow_splitting: true).
                 convert("jpg")

      pipeline.call(destination: full_size_file)

      # If there were multiple layers, ImageMagick saves them as 1234-N.jpg.
      unless File.exist?(full_size_file)
        biggest_layer = Dir.glob("#{local_images_path}/orig/#{@id}-*.jpg").first
        if File.exist?(biggest_layer)
          # Take the first one, and delete the rest.
          File.write(full_size_file, File.read(biggest_layer))
          File.delete(Dir.glob("#{local_images_path}/orig/#{@id}-*.jpg"))
        end
      end

      # Strip GPS out of header of raw_file if hiding coordinates.
      strip_gps_from_file(raw_file) if @strip_gps
    end

    def auto_orient_if_needed(file_path)
      file_to_orient = MiniMagick::Image.open(file_path)
      original_orientation = file_to_orient["%[orientation]"]
      file_to_orient.auto_orient
      new_orientation = file_to_orient["%[orientation]"]

      file_to_orient.write(file_path) if original_orientation != new_orientation
    end

    def update_image_record_width_and_height
      width, height = FastImage.size(full_size_file)
      @image.update(width: width, height: height)
    end

    def make_file_sizes
      SIZE_CONVERSIONS.each do |source, destination, size, quality|
        convert_source_to_destination(source, destination, size, quality)
      end
    end

    def convert_source_to_destination(source, destination, size, quality = 95)
      source_file = send(:"#{source}_file")
      destination_file = send(:"#{destination}_file")
      pipeline = ImageProcessing::MiniMagick.source(source_file).
                 append("-thumbnail", "#{size}x#{size}>").
                 append("-quality", quality).
                 convert("jpg")

      pipeline.call(destination: destination_file)
    end

    def transfer_files_to_image_servers
      return if Rails.env.development?

      @image_servers.each do |server|
        transfer_all_sizes_to_server_subdirectories(server)
      end
    end

    def transfer_all_sizes_to_server_subdirectories(server)
      subdirs = @image_server_data[server][:subdirs]
      image_subdirs.each do |subdir|
        if subdirs.include?(subdir)
          copy_file_to_server(server, "#{subdir}/#{@id}.jpg")
        end
      end
      if @ext != "jpg" && subdirs.include?("orig")
        copy_file_to_server(server, "orig/#{@id}.#{@ext}")
      end
      @transferred_any = 1
    end

    # Mark image as transferred and touch related obs (for caches) if all good
    def mark_image_record_transferred
      @image.update(
        transferred: @transferred_any
        # upload_status: "success"
      )
      Observation.joins(:observation_images).
        where(observation_images: { image_id: @id }).touch_all
    end

    # Email webmaster if there were any errors
    def email_webmaster
      QueuedEmail::Webmaster.create_email(
        sender_email: @user.email,
        subject: "[MO] process_image",
        content: @errors.join("\n")
      )
    end

    def image_subdirs
      Image::URL::SUBDIRECTORIES.values
    end

    def local_images_path
      MO.local_image_files
    end

    def image_servers
      MO.image_sources.each_key.map(&:to_s)
    end

    # NOTE: must use Addressable::URI to get "user@host:port" `authority`
    def image_server_data
      data = {
        local: {
          url: "file://#{local_images_path}",
          type: "file",
          path: local_images_path,
          subdirs: image_subdirs
        }
      }

      MO.image_sources.each do |server, specs|
        next unless specs[:write]

        uri = Addressable::URI.parse(specs[:write])
        data[server] = {
          url: format(specs[:write], root: MO.root),
          type: uri.scheme,
          path: uri.authority + uri.path,
          subdirs: specs[:sizes] || image_subdirs
        }
      end
      data
    end

    # Original file locations
    def raw_file
      "#{local_images_path}/orig/#{@id}.#{@ext}"
    end

    # full_size, huge, large, medium, small, thumbnail
    Image::URL::SUBDIRECTORIES.each do |size, subdir|
      define_method(:"#{size}_file") do
        "#{local_images_path}/#{subdir}/#{@id}.jpg"
      end
    end

    ############################################################

    def copy_file_to_server(server, local_file, remote_file = local_file)
      case @image_server_data[server][:type]
      when "file"
        copy_file_to_local_server(server, local_file, remote_file)
      when "ssh"
        copy_file_to_remote_server(server, local_file, remote_file)
      else
        raise("Unknown image server type: #{@image_server_data[server][:type]}")
      end
    end

    def copy_file_to_local_server(server, local_file, remote_file)
      return unless (remote_path = image_server_data[server][:path])

      FileUtils.cp("#{local_images_path}/#{local_file}",
                   "#{remote_path}/#{remote_file}")
    end

    # Rsync is used to copy files to the image server(s).
    def copy_file_to_remote_server(server, local_file, remote_file)
      return unless (remote_path = image_server_data[server][:path])

      Rsync.run("#{local_images_path}/#{local_file}",
                "#{remote_path}/#{remote_file}") do |result|
        if result.success?
          # result.changes.each do |change|
          #   puts("#{change.filename} (#{change.summary})")
          # end
        else
          @errors << result.error
        end
      end
    end

    # This method could potentially present a security risk depending on how the
    # remote_file parameter is being passed. If an attacker can control the
    # remote_file parameter, they could potentially use path traversal attacks
    # (../) to read arbitrary files from the remote server if the server is not
    # properly configured to prevent this.

    # To mitigate this risk, you should: Ensure that the remote_file parameter
    # is properly sanitized before it's used. For example, you could ensure that
    # it doesn't contain any ../ sequences or other special characters that
    # could be used in a path traversal attack.

    # Consider using a secure method to generate the local file path, rather
    # than directly using the remote_file parameter. For example, you could use
    # a hash of the remote_file parameter, or generate a random filename.

    # Make sure that the remote server is properly configured to prevent path
    # traversal attacks. For example, it should not allow requests for paths
    # that contain ../ or other special sequences.

    # Always use secure connections (HTTPS) when transferring files to prevent
    # man-in-the-middle attacks.
    def copy_file_from_server(server, remote_file)
      case @image_server_data[server][:type]
      when "file"
        copy_file_from_local_server(server, remote_file)
      when "ssh"
        copy_file_from_remote_server(server, remote_file)
      when "http"
        copy_file_from_http_server(server, remote_file)
      else
        raise("Don't know how to get #{remote_file} from #{server} via: " \
              "#{@image_server_data[server][:type]}")
      end
    end

    def copy_file_from_local_server(server, remote_file)
      return unless (remote_path = image_server_data[server][:path])

      FileUtils.cp("#{remote_path}/#{remote_file}",
                   "#{local_images_path}/#{remote_file}")
    end

    def copy_file_from_remote_server(server, remote_file)
      return unless (remote_path = image_server_data[server][:path])

      Rsync.run("#{remote_path}/#{remote_file}",
                "#{local_images_path}/#{remote_file}")
    end

    def copy_file_from_http_server(server, remote_file)
      return unless (remote_path = image_server_data[server][:path])

      case io = OpenURI.open_uri("#{remote_path}/#{remote_file}")
      when StringIO
        File.write("#{local_images_path}/#{remote_file}", io.read)
      when Tempfile
        io.close
        FileUtils.mv(io.path, "#{local_images_path}/#{remote_file}")
      end
    end
  end
end
