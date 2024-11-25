#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    script/reset_user_original_image_quotas.rb
#
#  DESCRIPTION::
#
#  This just resets all of the user original image quotas to zero.
#
################################################################################

require(File.expand_path("../config/boot.rb", __dir__))
require(File.expand_path("../config/environment.rb", __dir__))

User.update_all(original_image_quota: 0)

exit 0
