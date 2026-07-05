# frozen_string_literal: true

require("open3")
require("tempfile")

class Image
  # 64-bit difference hash ("dHash") for content-based image identity
  # (#4585 reflection resolution, #4673 duplicate detection). The hash is
  # computed from a 9x8 grayscale reduction of the image, so it is invariant
  # across resolutions and recompression — the same photo at iNat's medium
  # size and MO's original produce (near-)identical hashes. Compare hashes
  # with .distance (Hamming distance): 0 = same image, small = near-dup.
  #
  # Decoding/reduction is done by ImageMagick, already a server dependency
  # of script/process_image; no image-processing gem required.
  class Dhash
    WIDTH = 9
    HEIGHT = 8
    USER_AGENT = "MushroomObserver (+https://mushroomobserver.org)"

    # Raised when ImageMagick fails or produces unexpected output.
    # (Multi-line, not `class Error < ...; end` on one line, so the
    # localization_files_test class/end nesting scanner stays balanced.)
    class Error < ::StandardError
    end

    class << self
      def from_file(path)
        bits_from(grayscale_pixels(path))
      end

      # Fetch a remote rendition to a tempfile and hash it.
      def from_url(url)
        Tempfile.create(["dhash", ".img"], binmode: true) do |file|
          file.write(RestClient.get(url, user_agent: USER_AGENT).body)
          file.flush
          from_file(file.path)
        end
      end

      # Hamming distance between two hashes: number of differing bits.
      def distance(hash_a, hash_b)
        (hash_a ^ hash_b).to_s(2).count("1")
      end

      private

      # Each bit records whether a pixel is brighter than its right-hand
      # neighbor, row by row: 8 rows x 8 comparisons = 64 bits.
      def bits_from(pixels)
        hash = 0
        HEIGHT.times do |row|
          (WIDTH - 1).times do |col|
            left = pixels[(row * WIDTH) + col]
            right = pixels[(row * WIDTH) + col + 1]
            hash = (hash << 1) | (left > right ? 1 : 0)
          end
        end
        hash
      end

      # "[0]" selects the first frame/page of animated GIFs and multi-page
      # TIFFs; -auto-orient bakes in EXIF rotation so originals and
      # (already-rotated) renditions hash alike.
      #
      # Open3.capture3 is called in argv (list) form, so no shell is
      # spawned and each argument reaches convert verbatim — the
      # interpolations cannot be interpreted as shell syntax. `path` is
      # never user input either: it is an internally built absolute path
      # (Image#full_filepath, or a Tempfile) so it can't begin with "-"
      # and be mistaken for an option. (Brakeman command-injection warning
      # ignored on this basis in config/brakeman.ignore.)
      def grayscale_pixels(path)
        out, err, status = Open3.capture3(
          "convert", "#{path}[0]", "-auto-orient", "-colorspace", "Gray",
          "-resize", "#{WIDTH}x#{HEIGHT}!", "-depth", "8", "gray:-"
        )
        unless status.success? && out.bytesize == WIDTH * HEIGHT
          raise(Error.new("ImageMagick failed for #{path} " \
                          "(status #{status.exitstatus}): #{err.strip}"))
        end

        out.bytes
      end
    end
  end
end
