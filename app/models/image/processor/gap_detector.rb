# frozen_string_literal: true

require("open3")

class Image
  class Processor
    # Occasional reconciliation pass (see #4791's target design, part 4):
    # lists what's actually on each configured server (cheap, because
    # listing is local to that host -- one `find`/`Dir.glob` per server,
    # not per image), cross-references against the DB to find images
    # missing an expected size on a server that should have it, and
    # attempts to regenerate the missing size(s) from the original before
    # re-transferring. Meant to run rarely (weekly) -- unlike Verifier,
    # this lists full server contents rather than checking a work-list of
    # specific known paths.
    #
    # This catches drift Verifier/TransferImagesJob structurally can't:
    # once an image's local copies are deleted (the normal, desired
    # post-transfer state), there's no local byte count left to compare a
    # remote file against -- only a full listing can notice a file that
    # later vanished from a server that should still have it.
    class GapDetector
      def initialize(&log)
        @log = log
        @gaps = []
        @regenerated = []
        @unregenerable = []
        @image_server_data = Processor.image_server_data
        @image_servers = @image_server_data.keys - [:local]
      end

      # images defaults to every already-transferred image -- a
      # still-processing image is Verifier/TransferImagesJob's concern,
      # not a "gap" (see Verifier#transfer_image's same distinction).
      # Accepts an explicit override so tests can scope a run to just the
      # image(s) they've set up, instead of scanning every fixture in the
      # test database.
      def run(images = Image.where(transferred: true))
        listings = build_listings
        find_gaps(listings, images).each do |image, server, path|
          handle_gap(image, server, path)
        end
        { gaps: @gaps, regenerated: @regenerated,
          unregenerable: @unregenerable }
      end

      private

      def build_listings
        @image_servers.index_with { |server| list_server(server) }
      end

      def list_server(server)
        data = @image_server_data[server]
        data[:subdirs].each_with_object({}) do |subdir, files|
          log("Listing #{server} #{subdir}")
          list_subdir(server, data, subdir).each do |name, size|
            files["#{subdir}/#{name}"] = size
          end
        end
      end

      # "file" is a local (or locally-mounted) path -- Dir.glob it
      # directly. "ssh" is a real remote host -- shell out, matching how
      # the original script/bash_images' read_server_directory handled it.
      def list_subdir(server, data, subdir)
        case data[:type]
        when "file"
          list_local_subdir("#{data[:path]}/#{subdir}")
        when "ssh"
          list_ssh_subdir(server, data[:path], subdir)
        else
          raise("Don't know how to list #{server} via: #{data[:type]}")
        end
      end

      def list_local_subdir(path)
        Dir.glob("#{path}/*").each_with_object({}) do |file_path, files|
          next unless File.file?(file_path)

          files[File.basename(file_path)] = File.size(file_path)
        end
      end

      def list_ssh_subdir(server, remote_path, subdir)
        host, path = remote_path.split(":", 2)
        output, err, status = Open3.capture3(
          "ssh", host, "find", "-L", "#{path}/#{subdir}", "-maxdepth", "1",
          "-type", "f", "-printf", "%f\\t%s\\n"
        )
        unless status.success?
          log("Failed to list #{host}:#{path}/#{subdir} on " \
              "#{server}: #{err.strip}")
          return {}
        end

        parse_find_output(output)
      end

      def parse_find_output(output)
        output.each_line.with_object({}) do |line, files|
          name, size = line.chomp.split("\t")
          files[name] = size.to_i if name.present?
        end
      end

      def find_gaps(listings, images)
        gaps = []
        images.find_each do |image|
          paths = paths_for(image)
          @image_servers.each do |server|
            paths_for_server(server, paths).each do |path|
              gaps << [image, server, path] unless listings[server].key?(path)
            end
          end
        end
        gaps
      end

      def paths_for(image)
        paths = Image::URL::SUBDIRECTORIES.values.map do |subdir|
          "#{subdir}/#{image.id}.jpg"
        end
        ext = image.original_extension
        paths << "orig/#{image.id}.#{ext}" if ext != "jpg"
        paths
      end

      def paths_for_server(server, paths)
        subdirs = @image_server_data[server][:subdirs]
        paths.select { |path| subdirs.include?(subdir_of(path)) }
      end

      def subdir_of(path)
        path.split("/", 2).first
      end

      def handle_gap(image, server, path)
        @gaps << [image.id, server, path]
        log("GAP: image #{image.id} missing #{path} on #{server}")
        regenerate(image)
      end

      # Regenerates every derivative size from the original, rather than
      # trying to reuse just the one missing size -- SIZE_CONVERSIONS
      # chains each size from the next-larger one (regenerating "small"
      # needs "medium", which needs "huge"...), so anything short of the
      # full original as source cascades back to it anyway. Once
      # regenerated, hands off to Verifier to push whatever's actually
      # missing and clean up -- reuses the same upload/verify/delete
      # logic as the normal transfer path instead of re-implementing it.
      # One attempt per image per run: further gaps on the same image
      # are still recorded in @gaps (every affected path is alert-worthy),
      # but don't trigger repeat regeneration attempts.
      def regenerate(image)
        return if attempted?(image)

        regenerate_and_retransfer(image)
        @regenerated << image.id
      rescue StandardError => e
        @unregenerable << image.id
        log("Could not regenerate image #{image.id}: #{e.message}")
      end

      def attempted?(image)
        @regenerated.include?(image.id) || @unregenerable.include?(image.id)
      end

      def regenerate_and_retransfer(image)
        processor = Image::Processor.new(image: image)
        processor.make_sure_we_have_full_size_locally
        processor.process
        Verifier.new(&@log).transfer(Image.where(id: image.id))
      end

      def log(msg)
        @log&.call(msg)
      end
    end
  end
end
