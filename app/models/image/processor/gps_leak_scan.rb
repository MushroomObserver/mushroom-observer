# frozen_string_literal: true

require("open3")

class Image
  class Processor
    # Tripwire scan for GPS tags that survived the strip pipeline
    # (GitHub issue #4859): checks the given images' original files ON
    # the ssh-type image server(s), where the served copies live, via
    # one remote exiftool call per chunk of paths. Header-only reads
    # (-fast2, EXIF/XMP sit at the front of a JPEG), so scanning a
    # couple of weeks of gps_hidden uploads costs seconds.
    #
    # Why this exists: three separate mechanisms (the pre-#4791
    # verify_images 4am "repair", the pre-#4858 strip/transfer race,
    # and the strip-vs-first-archival race) each silently restored or
    # preserved GPS on files every DB flag said were clean, for years.
    # Only a periodic check of the actual served bytes catches the
    # class rather than a known instance.
    class GpsLeakScan
      # Truthiness, not `defined` -- with -m an absent tag interpolates
      # to "" (which IS defined), so `defined $tag` matches every file.
      GPS_CONDITION = "$GPS:GPSLatitude or $GPS:GPSLongitude or " \
                      "$XMP:GPSLatitude or $XMP:GPSLongitude"
      CHUNK = 400
      # BatchMode fails fast instead of hanging on a password/host-key
      # prompt; without these a single dead host could wedge the
      # recurring job's worker indefinitely.
      SSH_OPTIONS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10"].freeze

      def initialize(&log)
        @log = log
        @image_server_data = Processor.image_server_data
      end

      # Returns ids of images whose orig file still carries GPS lat/lng
      # on any ssh image server.
      def scan(images)
        paths = images.flat_map { |image| paths_for(image) }
        return [] if paths.empty?

        ssh_servers.flat_map { |server| hits_on(server, paths) }.uniq.sort
      end

      private

      def ssh_servers
        @image_server_data.select do |_server, data|
          data[:type] == "ssh" && data[:subdirs].include?("orig")
        end.keys
      end

      def paths_for(image)
        paths = ["orig/#{image.id}.jpg"]
        ext = image.original_extension
        paths << "orig/#{image.id}.#{ext}" if ext != "jpg"
        paths
      end

      def hits_on(server, paths)
        host, root = @image_server_data[server][:path].split(":", 2)
        paths.each_slice(CHUNK).flat_map do |chunk|
          remote_gps_hits(server, host, chunk.map { |p| "#{root}/#{p}" })
        end
      end

      # Hits come back one path per line. A missing file is routine
      # (files can be re-uploaded/renamed between candidate query and
      # scan) -- exiftool reports it on stderr and exits non-zero, the
      # same as when no file matches the -if, so the exit status is
      # ignored and only non-"File not found" stderr is worth logging.
      def remote_gps_hits(server, host, full_paths)
        command = "exiftool -q -q -m -fast2 -if '#{GPS_CONDITION}' " \
                  "-p '$directory/$filename' #{full_paths.join(" ")}"
        output, error, _status =
          Open3.capture3("ssh", *SSH_OPTIONS, host, command)
        report_real_errors(server, host, error)
        output.lines.filter_map { |line| line[%r{/(\d+)\.\w+\s*\z}, 1]&.to_i }
      end

      def report_real_errors(server, host, error)
        real = error.lines.reject { |line| line.include?("File not found") }
        return if real.empty?

        log("Errors checking #{host} for #{server}: #{real.join}")
      end

      def log(msg)
        @log&.call(msg)
      end
    end
  end
end
