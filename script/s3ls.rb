#!/usr/bin/env ruby
#
#  USAGE::
#
#    script/s3ls.rb server [--verbose]
#
#  DESCRIPTION::
#
#    Gets a list of files on the given S3 server.
#    NOTE: This takes *forever* and should only be run sparingly!!
#
#  PARAMETERS::
#
#    server     Primary key in MO.s3_credentials configuration hash.
#
################################################################################

app_root = File.expand_path("../..", __FILE__)
require "#{app_root}/app/classes/image_s3.rb"

server, verbose = ARGV

cache_file = "#{app_root}/public/images/#{server}.files"
temp_file = "#{app_root}/tmp/s3ls.#{Process.pid}"

# Hacky way to grab MO.s3_credentials from config files using script/config.rb.
cmd = File.expand_path("../../script/config.rb", __FILE__)
url               = `#{cmd} MO.s3_credentials[:#{server}][:server]`
bucket            = `#{cmd} MO.s3_credentials[:#{server}][:bucket]`
access_key_id     = `#{cmd} MO.s3_credentials[:#{server}][:access_key_id]`
secret_access_key = `#{cmd} MO.s3_credentials[:#{server}][:secret_access_key]`

s3 = ImageS3.new(
  server: url,
  bucket: bucket,
  access_key_id: access_key_id,
  secret_access_key: secret_access_key
)

num = 0
sum = 0
File.open(temp_file, "w") do |fh|
  s3.list.each do |obj|
    key  = obj.key
    size = obj.size
    num += 1
    sum += size
    fh.puts [key, size].join("\t")
    if verbose
      $stdout.write "#{sum} bytes in #{num} files...\r"
      $stdout.flush
    end
  end
end
if verbose
  $stdout.puts "#{sum} bytes in #{num} files"
end

FileUtils.mv(temp_file, cache_file, force: true)
exit 0
