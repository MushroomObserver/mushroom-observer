# frozen_string_literal: true

# All name_versions records created before the fix in PR #4257 have user_id
# equal to the name creator's user_id (copied from the name record by
# clone_versioned_model) because update_name_version never called ver.save.
# This migration uses each name's rss_log -- which always recorded the correct
# editor login -- to backfill the right user_id into each name_versions row.
class BackfillNameVersionUserIds < ActiveRecord::Migration[7.2]
  def up
    user_cache = {}

    Name.includes(:rss_log).find_each do |name|
      next unless name.rss_log

      # parse_log returns [tag, args, time] newest-first; reverse for
      # chronological order so we can reason about ordering.
      entries = name.rss_log.parse_log.reverse
      next if entries.empty?

      versions = Name::Version.where(name_id: name.id).order(:version).to_a
      next if versions.empty?

      versions.each do |version|
        next unless version.updated_at

        # Match to the log entry closest in time to the version's updated_at.
        # Both timestamps are second-precision; they should differ by ≤ 1 s
        # since save_version and user_log run in the same request.  We use a
        # generous 120 s window to absorb slow servers or retries.
        match = entries.min_by { |_, _, t| (t - version.updated_at).abs }
        next unless match

        _, args, time = match
        next if (time - version.updated_at).abs > 120

        login = args[:user].to_s
        next if login.blank? || login == "."

        user = user_cache[login] ||= User.find_by(login: login)
        next unless user
        next if version.user_id == user.id

        version.update_columns(user_id: user.id)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
