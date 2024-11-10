#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    script/purge_original_image_cache.rb
#
#  DESCRIPTION::
#
#  This just clears out old images from the local original image cache.
#
################################################################################

require(File.expand_path("../config/boot.rb", __dir__))
require(File.expand_path("../config/environment.rb", __dir__))

NUM_DAYS_TO_KEEP = 1

dir = MO.local_original_image_cache_path
Dir["#{dir}/*"].each do |file|
  path = "#{dir}/#{file}"
  next unless File.file?(path) &&
              (Time.current - File.stat(path).mtime) > 86_400 * NUM_DAYS_TO_KEEP

  File.delete(path)
end

exit 0
