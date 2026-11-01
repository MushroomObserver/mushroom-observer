# frozen_string_literal: true

# Stamps external_site_id on the source-derived namings and votes of
# existing iNat reflections (#4215): rows the importer created before
# the marker existed. A reflection's importer is its owner; their
# namings on it, and their votes on any of its namings, are the
# importer's work, since a person's own changes to a reflection go to
# its companion observation.
#
# Idempotent. Dry run by default; --apply to write.
apply = ARGV.delete("--apply")
abort("Unknown arguments: #{ARGV.join(" ")}") unless ARGV.empty?

site = ExternalSite.inaturalist
reflections = Observation.where.not(reflected_at: nil).
              joins(:external_links).
              where(external_links: { external_site_id: site.id,
                                      relationship: :import }).
              distinct
total = reflections.count
namings_seen = 0
votes_seen = 0
started = Time.zone.now

reflections.find_each.with_index(1) do |obs, i|
  namings = obs.namings.where(user_id: obs.user_id, external_site_id: nil)
  votes = Vote.where(observation_id: obs.id, user_id: obs.user_id,
                     external_site_id: nil)
  naming_ids = namings.pluck(:id)
  vote_ids = votes.pluck(:id)
  unless naming_ids.empty? && vote_ids.empty?
    puts("obs #{obs.id}: namings #{naming_ids.inspect}, " \
         "votes #{vote_ids.inspect}")
    if apply
      namings.update_all(external_site_id: site.id)
      votes.update_all(external_site_id: site.id)
    end
    namings_seen += naming_ids.size
    votes_seen += vote_ids.size
  end
  next unless (i % 500).zero?

  warn("#{i}/#{total} reflections, #{(Time.zone.now - started).round}s")
end

verb = apply ? "stamped" : "would be stamped"
puts("#{total} reflections: #{namings_seen} namings and " \
     "#{votes_seen} votes #{verb}.")
unless apply
  puts("Dry run - nothing written. To apply: " \
       "bin/rails runner script/backfill_naming_provenance.rb --apply")
end
