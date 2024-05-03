# frozen_string_literal: true

# This is used by ProcessImageJob to resize and transfer uploaded images to
# the image server(s).  It is intended to run asynchronously.  One of these
# jobs is spwaned for each image uploaded.  It takes these steps:

# 1. convert original to jpeg if necessary
# 2. reorient it correctly if necessary
# 3. set size of original image in database if 'set' flag used
# 4. create the five smaller-sized copies
# 5. copy all files to the image server(s) if in production mode
# 6. email webmaster if there were any errors

# It ensures that no other processes are running ImageMagick or scp before
# it runs its own commands.  If another is running, it sleep a few seconds
# and tries again.

class Image
  class Processor
    require "image_processing/mini_magick"
    require "exiftool_vendored"
    require "mini_exiftool"

    # Use the vendored version of Exiftool.
    MiniExiftool.command = Exiftool.command
    # Store Exiftool's database in a temporary directory.
    MiniExiftool.pstore_dir = Rails.root.join("tmp").to_s

    PRIVATE_KEY_PATH = Rails.root.join("config", "id_rsa").to_s

    def initialize(args)
      @id = args[:id]
      @ext = args[:ext]
      @set_size = args[:set_size]
      @strip_gps = args[:strip_gps]
    end

    def perform
      perform_desc = "#{@id}, #{@ext}, #{@set_size}, #{@strip_gps}"
      log("Starting Image::Process.perform(#{perform_desc})")

      image = Image.find(@id)
      raise(:process_image_job_no_image.t) unless image

      # Convert the original image to a JPEG if not already.
      # Note this also calls strip_gps(raw_file), possibly redundant.
      convert_raw_to_jpg if @ext != "jpg"

      # Strip GPS out of header of full_file if hiding coordinates.
      strip_gps(full_file) if @strip_gps

      # Make sure full_file is oriented correctly. (auto-orient implicit)
      auto_orient_if_needed(full_file)

      # Update size of original image in database if 'set' flag used.
      update_image_width_and_height(image) if @set_size

      #   Make the sizes, each command a bit different.
      make_sizes

      #   Check if all transferred
      transferred = check_transferred

      #   Mark image as transferred if all good
      image.update(transferred: transferred) if transferred
      #   Touch obs if all good
      #   Email webmaster if there were any errors

      log("Done with Image::Process.perform(#{perform_args})")
    end

    private

    def image_root
      MO.local_image_files
    end

    def convert_raw_to_jpg
      pipeline = ImageProcessing::MiniMagick.
                 source(raw_file).
                 append("-quality", 90).
                 append("-auto-orient").
                 saver(allow_splitting: true).
                 convert("jpg")

      pipeline.call(destination: full_file)

      # If there were multiple layers, ImageMagick saves them as 1234-N.jpg.
      unless File.exist?(full_file)
        biggest_layer = Dir.glob("#{image_root}/orig/#{@id}-*.jpg").first
        if File.exist?(biggest_layer)
          # Take the first one, and delete the rest.
          File.write(full_file, File.read(biggest_layer))
          File.delete(Dir.glob("#{image_root}/orig/#{@id}-*.jpg"))
        end
      end

      # Strip GPS out of header of raw_file if hiding coordinates.
      strip_gps(raw_file) if @strip_gps
    end

    def auto_orient_if_needed(file_path)
      orientable = ImageProcessing::MiniMagick::Image.open(file_path)
      original_orientation = image["%[orientation]"]

      orientable.auto_orient

      new_orientation = image["%[orientation]"]

      image.write(file_path) if original_orientation != new_orientation
    end

    def strip_gps(file)
      working = MiniExiftool.new(file)
      gps_fields.each { |field| working[field] = nil }
      working["XMP:Geotag"] = nil
      working.save
    end

    def update_image_width_and_height(image)
      width, height = Jpegsize.dimensions(full_file)
      image.update(width: width, height: height)
    end

    def make_sizes
      convert_full_to_huge
      convert_huge_to_large
      convert_huge_to_medium
      convert_medium_to_small
      convert_small_to_thumb
    end

    def convert_full_to_huge
      pipeline = ImageProcessing::MiniMagick.source(full_file).
                 append("-thumbnail", "1280x1280>").append("-quality", 93).
                 convert("jpg")

      pipeline.call(destination: huge_file)
    end

    def convert_huge_to_large
      pipeline = ImageProcessing::MiniMagick.source(huge_file).
                 append("-thumbnail", "1280x1280>").append("-quality", 94).
                 convert("jpg")

      pipeline.call(destination: large_file)
    end

    def convert_huge_to_medium
      pipeline = ImageProcessing::MiniMagick.source(huge_file).
                 append("-thumbnail", "640x640>").append("-quality", 95).
                 convert("jpg")

      pipeline.call(destination: medium_file)
    end

    def convert_medium_to_small
      pipeline = ImageProcessing::MiniMagick.source(medium_file).
                 append("-thumbnail", "320x320>").append("-quality", 95).
                 convert("jpg")

      pipeline.call(destination: small_file)
    end

    def convert_small_to_thumbnail
      pipeline = ImageProcessing::MiniMagick.source(small_file).
                 append("-thumbnail", "160x160>").append("-quality", 95).
                 convert("jpg")

      pipeline.call(destination: thumbnail_file)
    end

    def check_transferred
      transferred_any = 0
      unless Rails.env.development?
        MO.image_servers.each do |server|
          transferred_any = check_transferred_to_server(server, transferred_any)
        end
      end
      transferred_any
    end

    def check_transferred_to_server(server, transferred_any = 0)
      subdirs = image_server_data[server][:subdirs]
      image_subdirs.each do |subdir|
        if subdirs.include?(subdir)
          copy_file_to_server(server, "#{subdir}/#{@id}.jpg")
        end
      end
      if @ext != "jpg" && subdirs.include?("orig")
        copy_file_to_server(server, "orig/#{@id}.#{@ext}")
      end
      transferred_any = 1
    end

    def copy_file_to_server(server, local_file, remote_file = local_file)
      Net::SCP.start(server, "username", keys: PRIVATE_KEY_PATH) do |scp|
        scp.upload!(local_file, remote_file)
      end
    end

    def image_subdirs
      %w[1280 960 640 320 orig thumb]
    end

    # def image_sizes
    #   %w[thumbnail small medium large huge full_size]
    # end

    # def size_to_subdir(size)
    #   case size
    #   when "thumbnail" then "thumb"
    #   when "small" then "320"
    #   when "medium" then "640"
    #   when "large" then "960"
    #   when "huge" then "1280"
    #   when "full_size" then "orig"
    #   else raise("Unknown size: #{size}")
    # end

    # def subdir_to_size(subdir)
    #   case subdir
    #   when "thumb" then "thumbnail"
    #   when "320" then "small"
    #   when "640" then "medium"
    #   when "960" then "large"
    #   when "1280" then "huge"
    #   when "orig" then "full_size"
    #   else raise("Unknown subdir: #{subdir}")
    # end

    # def image_server_data
    #   {

    #   }
    # end

    def raw_file(id, ext)
      "#{image_root}/orig/#{id}.#{ext}"
    end

    def full_file(id)
      "#{image_root}/orig/#{id}.jpg"
    end

    def huge_file(id)
      "#{image_root}/1280/#{id}.jpg"
    end

    def large_file(id)
      "#{image_root}/960/#{id}.jpg"
    end

    def medium_file(id)
      "#{image_root}/640/#{id}.jpg"
    end

    def small_file(id)
      "#{image_root}/320/#{id}.jpg"
    end

    def thumb_file(id)
      "#{image_root}/thumb/#{id}.jpg"
    end

    # rubocop:disable Metrics/MethodLength
    def gps_fields
      %w[
        GPSLatitude
        GPSLongitude
        GPSAltitude
        GPSLatitudeRef
        GPSLongitudeRef
        GPSAltitudeRef
        GPSTimeStamp
        GPSSatellites
        GPSStatus
        GPSMeasureMode
        GPSDOP
        GPSSpeedRef
        GPSSpeed
        GPSTrackRef
        GPSTrack
        GPSImgDirectionRef
        GPSImgDirection
        GPSMapDatum
        GPSDestLatitudeRef
        GPSDestLatitude
        GPSDestLongitudeRef
        GPSDestLongitude
        GPSDestBearingRef
        GPSDestBearing
        GPSDestDistanceRef
        GPSDestDistance
        GPSProcessingMethod
        GPSAreaInformation
        GPSDateStamp
        GPSDifferential
      ]
    end
    # rubocop:enable Metrics/MethodLength
  end
end
