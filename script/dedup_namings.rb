#!/usr/bin/env ruby
# frozen_string_literal: true

# One-time cleanup for #5186: deletes duplicate Namings (same
# observation_id, user_id, name_id), keeping the oldest of each group,
# so db/migrate/20260825021326_add_unique_index_to_namings.rb's unique
# index can be added. Referenced by that migration's comment. Namings
# with a NULL observation_id are excluded -- they don't collide in the
# unique index either.
#
# Recalculates consensus for every affected observation afterward,
# since deleting a naming cascades to its votes but doesn't otherwise
# touch the observation's cached consensus.
#
#   bin/rails runner script/dedup_namings.rb          # dry run
#   bin/rails runner script/dedup_namings.rb --apply   # write

apply = !ARGV.delete("--apply").nil?
abort("Unknown argument(s): #{ARGV.join(", ")}") unless ARGV.empty?

duplicate_keys = Naming.where.not(observation_id: nil).
                 group(:observation_id, :user_id, :name_id).
                 count.
                 select { |_key, count| count > 1 }.
                 keys

if duplicate_keys.empty?
  warn("No duplicate namings found. Nothing to do.")
  exit
end

affected_observation_ids = Set.new

duplicate_keys.each do |observation_id, user_id, name_id|
  namings = Naming.where(observation_id:, user_id:, name_id:).order(:id).to_a
  survivor = namings.shift
  namings.each do |dup|
    warn("obs=#{observation_id} user=#{user_id} name=#{name_id}: " \
         "deleting naming ##{dup.id}, keeping ##{survivor.id} " \
         "#{apply ? "(applying)" : "(dry run)"}")
    next unless apply

    dup.destroy!
    affected_observation_ids << observation_id
  end
end

if apply
  affected_observation_ids.each do |obs_id|
    obs = Observation.naming_includes.find(obs_id)
    Observation::NamingConsensus.new(obs).calc_consensus
  end
  warn("APPLIED. Recalculated consensus for " \
       "#{affected_observation_ids.size} observation(s).")
else
  warn("Dry run - nothing written. To apply: " \
       "bin/rails runner script/dedup_namings.rb --apply")
end
