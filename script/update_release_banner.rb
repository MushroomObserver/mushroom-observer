# frozen_string_literal: true

# Sets the first line of the site banner once a deploy is up. Run by
# script/deploy.sh; safe to re-run by hand.
#
#   Dry run (default -- reports what WOULD change, writes nothing):
#     bundle exec rails runner script/update_release_banner.rb [--urgent]
#   Live run: add --apply
#
# A pre-release deploy says "<date> release complete". --urgent, for a
# forced deploy with no pre-release, says "Urgent release complete:
# <date> <time>". Either links the MO Article when the release is
# user-facing, else CHANGELOG.md on main. User-facing means
# article_pending.textile has rows (pre-release), or any PR merged since
# the last deploy tag has an `article: yes` changelog block (--urgent;
# read from GitHub, and treated as not user-facing if that fails).
#
# Saves a new Banner version, as the admin banner page does, so the banner
# reappears for visitors who dismissed the previous one. A banner whose
# first line already says this is left alone.

require_relative("release_notes")
require_relative("deployed_pulls")

SCRIPT = "bundle exec rails runner script/update_release_banner.rb"

def pre_release_user_facing?
  pending = ReleaseNotes::PENDING_FILE
  File.exist?(pending) && File.read(pending).strip.present?
end

def urgent_user_facing?
  pulls, problems = DeployedPulls.fetch
  problems.each { |problem| warn("Couldn't read deployed PRs: #{problem}") }
  ReleaseNotes.user_facing?(pulls)
end

args = ARGV.dup
apply = args.delete("--apply") ? true : false
urgent = args.delete("--urgent") ? true : false
abort("Unknown arguments: #{args.join(" ")}") unless args.empty?

banner = Banner.current
unless banner
  puts("No banner; nothing to update.")
  exit(0)
end

now = Time.now.utc
line = if urgent
         ReleaseNotes.urgent_banner_line(now,
                                         user_facing: urgent_user_facing?)
       else
         ReleaseNotes.released_banner_line(
           now, user_facing: pre_release_user_facing?
         )
       end
message = ReleaseNotes.with_first_line(banner.message, line)

if message == banner.message
  puts("The banner already starts with: #{line}")
  exit(0)
end

puts("New first line for the banner:")
puts("  #{line}")

unless apply
  flags = urgent ? " --urgent" : ""
  puts("Dry run - nothing written. To apply: #{SCRIPT}#{flags} --apply")
  exit(0)
end

new_banner = Banner.create!(message: message, version: Banner.next_version)
puts("Done: banner version #{new_banner.version}.")
