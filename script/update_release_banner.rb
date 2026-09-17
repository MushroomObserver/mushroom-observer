# frozen_string_literal: true

# Sets the first line of the site banner once a deploy is up. Run by
# script/deploy.sh; safe to re-run by hand.
#
#   Dry run (default -- reports what WOULD change, writes nothing):
#     bundle exec rails runner script/update_release_banner.rb [--forced]
#   Live run: add --apply
#
# A pre-release deploy says "<date> release complete", linking the MO
# Article when article_pending.textile has rows, else CHANGELOG.md on
# main. --forced, for a deploy that skipped the pre-release, says
# "Undocumented forced deploy occurred <date> <time>".
#
# Saves a new Banner version, as the admin banner page does, so the banner
# reappears for visitors who dismissed the previous one. A banner whose
# first line already says this is left alone.

require_relative("release_notes")

SCRIPT = "bundle exec rails runner script/update_release_banner.rb"

args = ARGV.dup
apply = args.delete("--apply") ? true : false
forced = args.delete("--forced") ? true : false
abort("Unknown arguments: #{args.join(" ")}") unless args.empty?

banner = Banner.current
unless banner
  puts("No banner; nothing to update.")
  exit(0)
end

now = Time.now.utc
line = if forced
         ReleaseNotes.forced_banner_line(now)
       else
         pending = ReleaseNotes::PENDING_FILE
         user_facing = File.exist?(pending) && File.read(pending).strip.present?
         ReleaseNotes.released_banner_line(now, user_facing: user_facing)
       end
message = ReleaseNotes.with_first_line(banner.message, line)

if message == banner.message
  puts("The banner already starts with: #{line}")
  exit(0)
end

puts("New first line for the banner:")
puts("  #{line}")

unless apply
  flags = forced ? " --forced" : ""
  puts("Dry run - nothing written. To apply: #{SCRIPT}#{flags} --apply")
  exit(0)
end

new_banner = Banner.create!(message: message, version: Banner.next_version)
puts("Done: banner version #{new_banner.version}.")
