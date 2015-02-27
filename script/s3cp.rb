#!/usr/bin/env ruby
#
#  USAGE::
#
#    script/s3cp.rb file server key [--update-cache]
#
#  DESCRIPTION::
#
#    Uploads a single local file to an S3 server.
#
#  PARAMETERS::
#
#    file            Source file.
#    server          Primary key in MO.s3_credentials configuration hash.
#    key             Key to store file under on S3 server.
#    --update-cache  Update cached listing for this server if successful.
#
################################################################################

app_root = File.expand_path("../..", __FILE__)
require "#{app_root}/app/classes/image_s3.rb"

file, server, key, update = ARGV

if !File.exists? file
  $stderr.puts("File doesn't exist: #{file.inspect}")
  exit 1
end

if update && update != "--update-cache"
  $stderr.puts("Invalid parameter: #{update.inspect}")
  exit 1
end

cache_file = "#{app_root}/public/images/#{server}.files"
size = File.size(file)
md5  = `md5sum #{file}`.split.first
type = `file --mime-type #{file}`.split.last

# Hacky way to grab MO.s3_credentials from config files using script/config.rb.
cmd = File.expand_path("../../script/config.rb", __FILE__)
url               = `#{cmd} MO.s3_credentials[:#{server}][:server]`
bucket            = `#{cmd} MO.s3_credentials[:#{server}][:bucket]`
access_key_id     = `#{cmd} MO.s3_credentials[:#{server}][:access_key_id]`
secret_access_key = `#{cmd} MO.s3_credentials[:#{server}][:secret_access_key]`

begin
  s3 = ImageS3.new(
    server: url,
    bucket: bucket,
    access_key_id: access_key_id,
    secret_access_key: secret_access_key
  )
rescue => e
  $stderr.puts("Upload failed on #{server}/#{key}: couldn't connect: #{e}");
  exit 1
end

begin
  result = s3.upload(key, file, content_type: type)
  if result.etag != "\"#{md5}\""
    $stderr.puts("Upload failed on #{server}/#{key}: md5sum didn't match")
    s3.delete(key) rescue nil
    exit 1
  end
rescue => e
  $stderr.puts("Upload failed on #{server}/#{key}: #{e}")
  exit 1
end

if update
  File.open(cache_file, "a") do |fh|
    fh.puts [key, size].join("\t")
  end
end

exit 0
