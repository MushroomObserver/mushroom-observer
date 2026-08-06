# frozen_string_literal: true

# Raises project memberships still sitting on the "hidden_gps" trust
# level they were never asked about, to the "editing" level every
# enrollment path now grants.
#
#   bin/rails runner script/upgrade_untouched_hidden_gps_trust.rb
#   bin/rails runner script/upgrade_untouched_hidden_gps_trust.rb --apply
#
# "Allow project admins to edit associated observations by default"
# (2025-07-11) set that default for the add-member and join paths, but
# project creation and `Project#join` kept handing out "hidden_gps", so
# creators in particular ended up as the one admin whose observations
# their co-admins could not edit.
#
# Only rows whose `updated_at` still matches their `created_at` are
# touched. A member who has been to the trust modal chose what they
# have, whatever they chose, and is left alone.

APPLY = ARGV.delete("--apply")
abort("Unknown argument(s): #{ARGV.join(" ")}") if ARGV.any?

# Timestamps are written together on insert but not to the same
# fractional second, so "never updated" needs a little slack rather
# than equality.
UNTOUCHED_SLACK = 2.seconds

def untouched?(member)
  (member.updated_at - member.created_at).abs <= UNTOUCHED_SLACK
end

candidates = ProjectMember.hidden_gps.includes(:project, :user).to_a
untouched, chosen = candidates.partition { |m| untouched?(m) }

warn("hidden_gps memberships: #{candidates.size}")
warn("  never changed since creation (will be raised): #{untouched.size}")
warn("  changed at some point (left alone):            #{chosen.size}")
chosen.each do |m|
  warn("    keeping #{m.user&.login} on #{m.project&.title.inspect} " \
       "(changed #{m.updated_at})")
end

creators = untouched.count { |m| m.project&.user_id == m.user_id }
warn("  of those to raise, #{creators} are the project's creator, " \
     "#{untouched.size - creators} are other members")

untouched.each_slice(100).with_index do |slice, batch|
  slice.each do |member|
    warn("  #{member.user&.login} on #{member.project&.title.to_s[0, 50]} " \
         "hidden_gps -> editing")
    # update_column, so `updated_at` keeps saying "this member has
    # never chosen a trust level" -- which stays true, and is what any
    # later analysis of deliberate choices needs to rely on.
    member.update_column(:trust_level, ProjectMember.trust_levels[:editing]) if
      APPLY
  end
  warn("  ...#{[(batch + 1) * 100, untouched.size].min}/#{untouched.size}")
end

warn("")
if APPLY
  warn("Raised #{untouched.size} membership(s) to editing.")
else
  warn("Dry run - nothing written. To apply: bin/rails runner " \
       "script/upgrade_untouched_hidden_gps_trust.rb --apply")
end
