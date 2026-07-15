# frozen_string_literal: true

require("open3")

class Image
  class Processor
    # Shared remote-file presence/size checks, used by both Verifier
    # (per-image, at transfer time) and GapDetector (batched, reconciling
    # already-transferred images). Checks specific paths directly -- one
    # `find -maxdepth 0` over the given paths per call, never a directory
    # listing. Includers must set @image_server_data and provide #log.
    module RemoteFiles
      private

      # Byte sizes of the given paths that exist on the server; a missing
      # path is absent (ssh) or nil (file), so callers check `[path].nil?`.
      def remote_sizes_for(server, paths)
        return {} if paths.empty?

        data = @image_server_data[server]
        case data[:type]
        when "file"
          paths.index_with { |path| remote_file_size(data[:path], path) }
        when "ssh"
          ssh_sizes(server, data[:path], paths)
        else
          raise("Don't know how to check #{server} via: #{data[:type]}")
        end
      end

      def remote_file_size(root, path)
        full = "#{root}/#{path}"
        File.exist?(full) ? File.size(full) : nil
      end

      # Checks every given path in a single ssh call. `-L` follows
      # symlinks; `-printf "%p\t%s"` gives "path\tsize" lines with no shell
      # quoting to parse around.
      def ssh_sizes(server, remote_path, paths)
        host, root = remote_path.split(":", 2)
        full_paths = paths.map { |path| "#{root}/#{path}" }
        # The -printf format MUST be single-quoted: ssh joins the argv
        # into one string and the *remote* shell re-parses it, stripping
        # the backslashes from an unquoted %p\t%s\n -- find would then emit
        # literal "t"/"n" separators and the output couldn't be split
        # (every path would read as missing). The unit tests stub Open3,
        # so they can't catch this; it only shows against a real host.
        output, error, status = Open3.capture3(
          "ssh", host, "find", "-L", *full_paths, "-maxdepth", "0",
          "-printf", "'%p\\t%s\\n'"
        )
        if connection_failed?(status, error)
          log("Failed to check #{host} for #{server}: #{error}")
        end
        parse_find_output(output, root)
      end

      # `find` exits non-zero (one "No such file or directory" on stderr
      # per missing path) whenever ANY requested path is missing -- the
      # routine, expected case, not a failure. Only other stderr
      # (ssh/auth/command errors) counts as a real failure.
      def connection_failed?(status, error)
        return false if status.success?

        error.lines.any? { |line| line.exclude?("No such file or directory") }
      end

      def parse_find_output(output, root)
        output.each_line.with_object({}) do |line, sizes|
          full_path, size = line.chomp.split("\t")
          next if full_path.blank?

          sizes[full_path.delete_prefix("#{root}/")] = size.to_i
        end
      end

      def paths_for_server(server, paths)
        subdirs = @image_server_data[server][:subdirs]
        paths.select { |path| subdirs.include?(subdir_of(path)) }
      end

      def subdir_of(path)
        path.split("/", 2).first
      end
    end
  end
end
