# frozen_string_literal: true

# Collapse duplicate namings -- same (observation_id, user_id, name_id) --
# onto the lowest-id naming, then delete the rest (#5186). Per-observation
# by construction, so occurrence members keep their own copies.
#
# Votes migrate onto the keeper: per voter, the highest value wins (matching
# the consensus calculation), and `favorite` is the OR of that voter's votes
# in the group. Reasons merge onto the keeper: an identical reason+text is
# kept once; the same reason number with different text is concatenated as
# separate sentences. Consensus is recalculated for each touched observation.
#
# Dry run (default -- reports, writes nothing; flags groups whose reasons
# differ for human review before applying):
#   bin/rails runner script/dedup_namings.rb
# Apply:
#   bin/rails runner script/dedup_namings.rb --apply

apply = ARGV.include?("--apply")
extra = ARGV - ["--apply"]
unless extra.empty?
  abort("Unknown args: #{extra.inspect}\n" \
        "Usage: bin/rails runner script/dedup_namings.rb [--apply]")
end

# num => [notes string per naming that used it] across the group.
def collected_reasons(namings)
  collected = Hash.new { |h, k| h[k] = [] }
  namings.each do |naming|
    (naming.reasons || {}).each do |num, notes|
      collected[num] << notes.to_s.strip
    end
  end
  collected
end

def join_sentences(texts)
  "#{texts.map { |t| t.sub(/\s*\.\s*\z/, "") }.join(". ")}."
end

# num => merged notes string across the group's namings.
def merge_reasons(namings)
  collected_reasons(namings).transform_values do |notes_list|
    distinct = notes_list.compact_blank.uniq
    distinct.empty? ? "" : join_sentences(distinct)
  end
end

# True when the namings carry differing reasons (a different set of used
# reason numbers, or the same number with >1 distinct non-blank text) --
# the cases worth a human's eyes before applying.
def reasons_differ?(namings)
  used_sets = namings.map { |n| (n.reasons || {}).keys.sort }.uniq
  return true if used_sets.size > 1

  collected_reasons(namings).values.any? do |list|
    list.compact_blank.uniq.size > 1
  end
end

# All votes across the group folded per voter -> [best_value, favorite?].
def votes_by_voter(namings)
  Vote.where(naming_id: namings.map(&:id)).group_by(&:user_id).
    transform_values do |votes|
      [votes.map(&:value).max, votes.any?(&:favorite)]
    end
end

def migrate_votes(keeper, folded_votes)
  folded_votes.each do |voter_id, (value, favorite)|
    vote = Vote.find_or_initialize_by(naming_id: keeper.id, user_id: voter_id)
    vote.observation_id = keeper.observation_id
    vote.assign_attributes(value: value, favorite: favorite)
    vote.save!
  end
end

def recalc_consensus(observation_id)
  obs = Observation.find(observation_id)
  obs.current_user = User.admin
  Observation::NamingConsensus.new(obs).calc_consensus(User.admin)
end

def apply_group!(keeper, dups, folded_votes, merged_reasons)
  Naming.transaction do
    migrate_votes(keeper, folded_votes)
    dups.each do |dup|
      dup.current_user = User.admin
      dup.destroy!
    end
    keeper.update!(reasons: merged_reasons)
    recalc_consensus(keeper.observation_id)
  end
end

groups = Naming.group(:observation_id, :user_id, :name_id).
         having(Arel.star.count.gt(1)).count.keys

foreign_vote_groups = 0
differing_reason_groups = []
extra_namings = 0
started = Time.zone.now

groups.each_with_index do |(obs_id, user_id, name_id), i|
  namings = Naming.where(observation_id: obs_id, user_id: user_id,
                         name_id: name_id).order(:id).to_a
  next if namings.size < 2

  keeper, *dups = namings
  extra_namings += dups.size
  folded_votes = votes_by_voter(namings)
  merged_reasons = merge_reasons(namings)
  foreign = folded_votes.keys.reject { |uid| uid == user_id }
  foreign_vote_groups += 1 if foreign.any?
  differs = reasons_differ?(namings)
  differing_reason_groups << [obs_id, namings.map(&:id)] if differs

  if ((i + 1) % 50).zero?
    warn("[#{i + 1}/#{groups.size}] " \
         "elapsed #{(Time.zone.now - started).round}s")
  end

  flag = differs ? " REASONS-DIFFER(review)" : ""
  puts("obs #{obs_id} user #{user_id} name #{name_id}: keep " \
       "#{keeper.id}, delete #{dups.map(&:id).inspect}; " \
       "voters #{folded_votes.size} (foreign #{foreign.size})#{flag}")

  apply_group!(keeper, dups, folded_votes, merged_reasons) if apply
end

puts("\n=== summary ===")
puts("duplicate groups:            #{groups.size}")
puts("extra namings to remove:     #{extra_namings}")
puts("groups with foreign votes:   #{foreign_vote_groups}")
puts("groups with differing reasons (HUMAN REVIEW): " \
     "#{differing_reason_groups.size}")
differing_reason_groups.each do |obs_id, ids|
  puts("   obs #{obs_id}: namings #{ids.inspect}")
end

if apply
  puts("\nApplied.")
else
  puts("\nDry run - nothing written. To apply: " \
       "bin/rails runner script/dedup_namings.rb --apply")
end
