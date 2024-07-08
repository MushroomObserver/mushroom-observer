#!/usr/bin/env ruby
# frozen_string_literal: true

# This is a one-time script, i'm just making it nice for practice
# call with `script/update_user_content_filter.rb "true"`

require(File.expand_path("../config/boot.rb", __dir__))
require(File.expand_path("../config/environment.rb", __dir__))
require(File.expand_path("../app/extensions/extensions.rb", __dir__))

abort(<<HELP) if ARGV.length != 1

  USAGE::

    ruby script/update_user_content_filter.rb "true"

  DESCRIPTION::

    Updates the keys of the serialized hash in `user`.`content_filter`
    to match the new keys in the `ContentFilter` class.

  PARAMETERS::

    --help     Print this message.

HELP

class UpdateUserContentFilter
  def self.update_users(dry_run)
    dry_run = dry_run.to_boolean
    entries = updatable_users
    User.upsert_all(entries) unless dry_run

    msgs = ["content_filter updated for #{entries.size} users."]
    msgs << "Dry run: no changes made." if dry_run
    p(msgs.join(" "))
  end

  def self.updatable_users
    entries = []
    User.pluck(:id, :content_filter).each do |user_id, content_filter|
      next if content_filter.blank?

      hsh = content_filter # the value is a serialized hash, already parsed here
      hsh[:with_images] = hsh.delete(:has_images) if hsh.key?(:has_images)
      hsh[:with_specimen] = hsh.delete(:has_specimen) if hsh.key?(:has_specimen)
      entries << { id: user_id, content_filter: hsh }
    end
    entries
  end
end

# This runs the first function with the first variable supplied to the script
UpdateUserContentFilter.update_users(ARGV[0])
