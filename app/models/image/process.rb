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
  class Process
    def initialize(args)
      @id = args[:id]
      @ext = args[:ext]
      @set_size = args[:set_size]
      @strip_gps = args[:strip_gps]
    end

    # def perform
    #   log("Starting Image::Process.perform(#{@id}, #{@ext}, #{@set_size}, #{@strip_gps})")
    #   image = Image.find(@id)
    #   raise(:process_image_job_no_image.t) unless image

    #   Convert the original image to a JPEG if not already.
    #    - If there are multiple layers, ImageMagick saves them as 1234-N.jpg.
    #      Take the first one, and delete the rest.
    #    - Strip GPS out of header if hiding coordinates. (2x?)

    #   Strip GPS out of header if hiding coordinates.

    #   Make sure image is oriented correctly.

    #   Set size of original image in database if 'set' flag used.

    #   Make the sizes, each command a bit different.
    #    convert -thumbnail "1280x1280>" -quality 93 $full_file $huge_file
    #    convert -thumbnail "960x960>"   -quality 94 $huge_file $large_file
    #    convert -thumbnail "640x640>"   -quality 95 $huge_file $medium_file
    #    convert -thumbnail "320x320>"   -quality 95 $medium_file $small_file
    #    convert -thumbnail "160x160>"   -quality 95 $small_file $thumb_file

    #   Check if all transferred
    #   Mark image as transferred if all good
    #   Touch obs if all good
    #   Email webmaster if there were any errors

    #   log("Done with Image::Process.perform(#{@id}, #{@ext}, #{@set_size}, #{@strip_gps})")
    # end

    private

    def image_root
      MO.local_image_files
    end

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
  end
end
