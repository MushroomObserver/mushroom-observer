#!/usr/bin/env ruby
# frozen_string_literal: true

# This is a one-time script, can be modified and reused in the future if Query
# params change and we need to purge existing QueryRecords of the old params.
#
# call with `script/update_query_records.rb "true"`

require(File.expand_path("../config/boot.rb", __dir__))
require(File.expand_path("../config/environment.rb", __dir__))
require(File.expand_path("../config/initializers/extensions.rb", __dir__))

abort(<<HELP) if ARGV.length != 1

  USAGE::

    ruby script/update_query_records.rb "true"

  DESCRIPTION::

    Updates the serialized description in `query_records`.`description`
    to match the new keys in the `Query::Filter` class.

  PARAMETERS::

    --help     Print this message.

HELP

class UpdateQueryRecords
  def self.update_query_records(dry_run:)
    dry_run = dry_run.to_boolean
    entries = updatable_query_records
    QueryRecord.upsert_all(entries) unless dry_run

    msgs = ["description updated for #{entries.size} query_records."]
    msgs << "Dry run: no changes made." if dry_run
    p(msgs.join(" "))
  end

  def self.updatable_query_records # rubocop:disable Metrics/AbcSize
    entries = []
    QueryRecord.pluck(:id, :description).each do |query_record_id, description|
      next if description.blank?

      # the value is a serialized hash, parsed here
      hsh = JSON.parse(description).deep_symbolize_keys
      next unless hsh.key?(:with_images) || hsh.key?(:with_specimen)

      hsh[:has_images] = hsh.delete(:with_images) if hsh.key?(:with_images)
      if hsh.key?(:with_specimen)
        hsh[:has_specimen] = hsh.delete(:with_specimen)
      end
      entries << { id: query_record_id, description: hsh.to_json }
    end
    entries
  end
end

# This runs the first function with the first variable supplied to the script
UpdateQueryRecords.update_query_records(dry_run: ARGV[0])
