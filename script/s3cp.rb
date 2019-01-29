#!/usr/bin/env ruby

app_root = File.expand_path("..", __dir__)
require "#{app_root}/app/classes/image_s3.rb"
require "fileutils"

abort(<<"EOB") if ARGV.any? { |arg| ["-h", "--help"].include?(arg) }

  USAGE::

    script/s3cp.rb file server key [--force]
    script/s3cp.rb --delete server key

  DESCRIPTION::

    The first form uploads a single local file to an S3 server.
    The second form deletes a single key from an S3 server.

    By default it will check the cached listing of what's on the server first
    to make sure the file hasn't already been uploaded.  It will add/remove the
    appropriate cache entry after successfully uploading/removing the file.

  PARAMETERS::

    file       Source file.
    server     Primary key in MO.s3_credentials configuration hash.
    key        Key to store file under on S3 server.
    --force    Upload file even if it's already been uploaded.
    --verbose  Print what's happening to stdout.
    --help     Print this message.

EOB

delete  = true if ARGV.any? { |arg| ["-d", "--delete"].include?(arg) }
force   = true if ARGV.any? { |arg| ["-f", "--force"].include?(arg) }
verbose = true if ARGV.any? { |arg| ["-v", "--verbose"].include?(arg) }
copy = !delete
flags = ARGV.select { |arg| arg.match(/^-/) }.
        reject { |arg| arg.match(/^(-d|-f|-v|--delete|--force|--verbose)$/) }
words = ARGV.reject { |arg| arg.match(/^-/) }
abort("Bad flag(s): #{flags.inspect}") if flags.length.positive?
if copy
  abort("Missing file!") if words.length.zero?
  file = words.shift
  abort("File doesn't exist: #{file.inspect}") unless File.exist?(file)
end
abort("Missing server!") if words.length.zero?
server = words.shift
abort("Missing key!") if words.length.zero?
key = words.shift
abort("Unexpected parameter(s): #{words.inspect}") if words.length.positive?

cache_file = "#{app_root}/public/images/#{server}.files"
temp_file  = "#{app_root}/tmp/#{server}.files.#{Process.pid}"

def log(msg)
  $stdout.write(msg)
  $stdout.flush
end

if copy
  size = File.size(file)
  md5  = `md5sum #{file}`.split.first
  type = `file --mime-type #{file}`.split.last

  # Trust cached listing: no need to resend a file if we've already logged it.
  unless force
    old_size, old_md5 = `grep ^#{key} #{cache_file} | tail -1`.split[1, 2]
    if old_size == size.to_s && old_md5 == md5
      log("Already uploaded #{server}/#{key}\n") if verbose
      exit 0
    end
  end
end

# Hacky way to grab MO.s3_credentials from config files using script/config.rb.
cmd = File.expand_path("../script/config.rb", __dir__)
url               = `#{cmd} MO.s3_credentials[:#{server}][:server]`
bucket            = `#{cmd} MO.s3_credentials[:#{server}][:bucket]`
access_key_id     = `#{cmd} MO.s3_credentials[:#{server}][:access_key_id]`
secret_access_key = `#{cmd} MO.s3_credentials[:#{server}][:secret_access_key]`
abort("Bad server: #{server.inspect}") unless url

begin
  log("Connecting...\r") if verbose
  s3 = ImageS3.new(
    server: url,
    bucket: bucket,
    access_key_id: access_key_id,
    secret_access_key: secret_access_key
  )
rescue => e
  abort("Upload failed on #{server}/#{key}: couldn't connect: #{e}")
end

if copy
  begin
    log("Uploading... \r") if verbose
    result = s3.upload(key, file, content_type: type)
    if result.etag != "\"#{md5}\""
      begin
        s3.delete(key)
      rescue
        nil
      end
      abort("Upload failed on #{server}/#{key}: md5sum didn't match")
    end
  rescue => e
    abort("Upload failed on #{server}/#{key}: #{e}")
  end
  log("Uploaded #{server}/#{key}\n") if verbose
  File.open(cache_file, "a") do |fh|
    fh.puts [key, size, md5].join("\t")
  end
end

if delete
  log("Deleting...  \r") if verbose
  s3.delete(key)
  log("Deleted #{server}/#{key}\n") if verbose
  FileUtils.touch(cache_file)
  FileUtils.mv(cache_file, temp_file)
  FileUtils.touch(cache_file)
  system("grep -v ^#{key} #{temp_file} >> #{cache_file}")
  FileUtils.rm(temp_file)
end

exit 0
