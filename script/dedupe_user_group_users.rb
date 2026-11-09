# frozen_string_literal: true

# One-time repair, the precondition for the unique index on
# user_group_users (#5636). Each duplicate is the same membership
# written twice, so the oldest row of each pair survives.
#
# Dry run (default -- reports, writes nothing):
#   bin/rails runner script/dedupe_user_group_users.rb
# Apply:
#   bin/rails runner script/dedupe_user_group_users.rb --apply

APPLY = ARGV.delete("--apply") ? true : false
if ARGV.any?
  warn("Unknown argument(s): #{ARGV.join(", ")}")
  warn("Usage: bin/rails runner script/dedupe_user_group_users.rb [--apply]")
  exit(1)
end

# Deletes all but the oldest row of each duplicated user_group_users
# membership.
class UserGroupUserDedupe
  REPORT_EVERY = 100

  def initialize(apply:)
    @apply = apply
    @started = Time.zone.now
  end

  def run
    puts(@apply ? "APPLYING changes." : "DRY RUN.")
    groups = duplicate_groups
    puts("\nuser_group_users: #{groups.size} duplicated pairs")
    extra = groups.each_with_index.sum do |(pair, ids), index|
      removed = dedupe_pair(pair, ids)
      progress(index + 1, groups.size)
      removed
    end
    summarize(groups.size, extra)
  end

  private

  def dedupe_pair((user_group_id, user_id), ids)
    keep, *drop = ids.sort
    puts("  user_group #{user_group_id} user #{user_id}: " \
         "keep #{keep}, delete #{drop.join(", ")}")
    UserGroupUser.where(id: drop).delete_all if @apply
    drop.size
  end

  # {[user_group_id, user_id] => [row ids]} for every pair with more
  # than one row.
  def duplicate_groups
    pairs = UserGroupUser.group(:user_group_id, :user_id).
            having(Arel.star.count.gt(1)).count.keys
    pairs.to_h do |user_group_id, user_id|
      [[user_group_id, user_id],
       UserGroupUser.where(user_group_id: user_group_id, user_id: user_id).
         pluck(:id)]
    end
  end

  def progress(done, total)
    return unless (done % REPORT_EVERY).zero? || done == total

    elapsed = (Time.zone.now - @started).round
    warn("user_group_users: #{done}/#{total} pairs, #{elapsed}s")
  end

  def summarize(pairs, extra)
    puts("\nSummary:")
    verb = @apply ? "deleted" : "would delete"
    puts("  user_group_users: #{pairs} duplicated pairs, #{verb} #{extra} " \
         "rows")
    return if @apply

    puts("Dry run - nothing written. To apply: " \
         "bin/rails runner script/dedupe_user_group_users.rb --apply")
  end
end

UserGroupUserDedupe.new(apply: APPLY).run
