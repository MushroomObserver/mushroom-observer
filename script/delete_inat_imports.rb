#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    script/delete_inat_imports.rb <login_or_id>
#
#  DESCRIPTION::
#
#    DEV TOOL: deletes all MO Observations that were imported from iNat for
#    the given user, along with their ExternalLinks (cascade). Also resets the
#    user's InatImport record (imported_count, total_imported_count, log) so
#    the same iNat observations can be re-imported cleanly.
#
#    Intended for local dev/testing only. Do NOT run against production.
#
#  EXAMPLES::
#
#    script/delete_inat_imports.rb rolf
#    script/delete_inat_imports.rb 3477
#

raise "Usage: script/delete_inat_imports.rb <login_or_id>" if ARGV.empty?

require File.expand_path("../config/environment", __dir__)

arg = ARGV.first
user = arg.match?(/\A\d+\z/) ? User.find_by(id: arg) : User.find_by(login: arg)
abort("User not found: #{arg}") unless user

puts "User: #{user.login} (id #{user.id})"

inat_site = ExternalSite.inaturalist
unless inat_site
  abort("ExternalSite for iNaturalist not found — is the DB seeded?")
end

import_links = ExternalLink.import.
               where(user: user,
                     target_type: "Observation",
                     external_site: inat_site)

obs_ids = import_links.pluck(:target_id)
puts "Found #{obs_ids.size} iNat-imported observation(s) for #{user.login}."

if obs_ids.empty?
  puts "Nothing to delete."
else
  print "Deleting... "
  destroyed = Observation.where(id: obs_ids).destroy_all
  puts "deleted #{destroyed.size} observation(s) " \
       "(ExternalLinks removed by cascade)."
end

inat_import = InatImport.find_by(user: user)
if inat_import
  inat_import.update(
    imported_count: 0,
    total_imported_count: 0,
    response_errors: "",
    log: []
  )
  puts "Reset InatImport##{inat_import.id} counters."
end

puts "Done. #{user.login} can now re-import the same iNat observations."
