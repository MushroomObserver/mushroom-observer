# frozen_string_literal: true

require("open-uri")

class Image
  class Processor
    # Copies one file between the local filesystem and a configured image
    # server. No per-image state -- shared by Image::Processor (per-upload
    # transfers) and Image::Processor::Verifier (bulk local/remote sync).
    module FileTransfer
      # Raised when rsync exits non-zero, carrying its exit code and
      # stderr. Without these, a failed upload logs only "Failed to upload
      # X to Y" -- a transient ssh/network blip (exit 30/255/12) then reads
      # identically to a full disk (11) or a permissions problem (23), and
      # only the exit code and stderr tell them apart. See
      # Verifier#upload_one_file, whose rescue logs this message.
      class RsyncError < StandardError; end

      def self.copy_file_to_server(server, local_file, remote_file = local_file)
        case Processor.image_server_data[server][:type]
        when "file"
          copy_file_to_local_server(server, local_file, remote_file)
        when "ssh"
          copy_file_to_remote_server(server, local_file, remote_file)
        else
          raise("Unknown image server type: " \
                "#{Processor.image_server_data[server][:type]}")
        end
      end

      def self.copy_file_from_server(server, remote_file,
                                     local_file = remote_file)
        case Processor.image_server_data[server][:type]
        when "file"
          copy_file_from_local_server(server, remote_file, local_file)
        when "ssh"
          copy_file_from_remote_server(server, remote_file, local_file)
        when "http", "https"
          copy_file_from_http_server(server, remote_file, local_file)
        else
          raise("Don't know how to get #{remote_file} from #{server} via: " \
                "#{Processor.image_server_data[server][:type]}")
        end
      end

      def self.copy_file_to_local_server(server, local_file, remote_file)
        return unless (remote_path = Processor.image_server_data[server][:path])

        FileUtils.mkpath(File.dirname("#{remote_path}/#{remote_file}"))
        FileUtils.cp("#{Processor.local_images_path}/#{local_file}",
                     "#{remote_path}/#{remote_file}")
        true
      end

      # Rsync is used to copy files to remote image server(s). Raises
      # RsyncError (exit code + stderr) rather than returning false on
      # failure, so the caller's log records why the upload failed instead
      # of a bare boolean.
      def self.copy_file_to_remote_server(server, local_file, remote_file)
        return unless (remote_path = Processor.image_server_data[server][:path])

        result = nil
        Rsync.run("#{Processor.local_images_path}/#{local_file}",
                  "#{remote_path}/#{remote_file}") { |r| result = r }
        return true if result.success?

        raise(RsyncError.new("rsync exited #{result.exitcode}: " \
                          "#{result.error.to_s.strip}"))
      end

      def self.copy_file_from_local_server(server, remote_file, local_file)
        return unless (remote_path = Processor.image_server_data[server][:path])

        local_path = "#{Processor.local_images_path}/#{local_file}"
        FileUtils.mkpath(File.dirname(local_path))
        FileUtils.cp("#{remote_path}/#{remote_file}", local_path)
        true
      end

      def self.copy_file_from_remote_server(server, remote_file, local_file)
        return unless (remote_path = Processor.image_server_data[server][:path])

        result = nil
        Rsync.run("#{remote_path}/#{remote_file}",
                  "#{Processor.local_images_path}/#{local_file}") do |r|
          result = r
        end
        result.success?
      end

      def self.copy_file_from_http_server(server, remote_file, local_file)
        return unless (remote_path = Processor.image_server_data[server][:path])

        local_path = "#{Processor.local_images_path}/#{local_file}"
        FileUtils.mkpath(File.dirname(local_path))
        # Tempfile (large responses): move it into place. Anything else
        # readable -- StringIO (small responses) or a generic IO -- gets
        # streamed; a non-IO makes IO.copy_stream raise rather than let
        # the method silently report success without writing anything.
        case io = URI.parse("#{remote_path}/#{remote_file}").open
        when Tempfile
          io.close
          FileUtils.mv(io.path, local_path)
        else
          IO.copy_stream(io, local_path)
        end
        true
      end
    end
  end
end
