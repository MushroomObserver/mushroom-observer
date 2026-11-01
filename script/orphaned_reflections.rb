# frozen_string_literal: true

# Every reflection whose iNaturalist source has been deleted, with the
# signals that decide what to do about it.
#
# Read-only: asks iNat for all reflections 200 ids at a time and reports
# the ones it does not return. An id queried explicitly and missing from
# the results is deleted at iNat -- the nightly batch cannot see this,
# because its updated_since fetch reads a missing id as "unchanged".
#
# Independent of the URL backfill and its logs: it derives the set from
# the database and iNat, so it can be re-run any time.
#
# The triage columns, and why each matters:
#   native    a non-reflection companion in the same occurrence holds
#             MO-native content; deleting the reflection needs the
#             occurrence-aware path (see #5269's stranding bugs)
#   people    comments, or namings a person typed (external_site nil)
#             from someone other than the owner -- a mirrored naming is
#             not engagement. Kingdom/Phylum/Class/Order names are
#             placeholders, not identifications.
#   attached  sequences, herbarium records, field slips, species lists
#   inat_user the observer's iNat login, read from the import notes --
#             the starting point for finding a live replacement
#
#   bin/rails runner script/orphaned_reflections.rb \
#     -- [projects/inat-sync/orphaned_reflections.txt]

class OrphanedReflections
  BATCH = Inat::ObsFetcher::PAGE_SIZE
  PLACEHOLDER_RANKS = %w[Kingdom Phylum Class Order].freeze
  ROW = "%-8s %-8s %-11s %-6s %-7s %-9s %-14s %s"

  def initialize(out_path)
    @out_path = out_path
    @lines = []
  end

  def run
    missing = find_missing
    warn("#{missing.size} reflections have no live iNat source.")
    report(missing)
    write_report
  end

  private

  # [inat_id, observation_id] for every reflection with an import link.
  def targets
    @targets ||= numbered.sort_by { |inat_id, _obs_id| -inat_id }
  end

  def numbered
    reflection_links.map do |external_id, obs_id|
      [external_id.to_i, obs_id]
    end
  end

  def reflection_links
    site = ExternalSite.find_by(name: ExternalSite::INATURALIST_NAME)
    reflections = Observation.where.not(reflected_at: nil).select(:id)
    ExternalLink.where(
      external_site_id: site&.id,
      relationship: ExternalLink.relationships[:import],
      target_type: "Observation", target_id: reflections
    ).pluck(:external_id, :target_id)
  end

  def find_missing
    fetcher = Inat::ObsFetcher.new
    missing = []
    targets.each_slice(BATCH).with_index do |batch, index|
      by_id, failed = fetcher.fetch_batch(batch.map(&:first))
      abort("batch fetch failed after retries; nothing written") if failed

      batch.each do |inat_id, obs_id|
        missing << [inat_id, obs_id] unless by_id[inat_id.to_s]
      end
      progress(index, missing.size)
      sleep(Inat::ObsFetcher::INTER_PAGE_SLEEP)
    end
    missing
  end

  def progress(index, found)
    return unless ((index + 1) % 10).zero?

    warn("  #{(index + 1) * BATCH} of #{targets.size} checked, " \
         "#{found} with no live source")
  end

  def report(missing)
    say(format(ROW, "mo", "inat", "when", "images", "native", "attached",
               "inat_user", "people (native, non-owner)"))
    missing.each { |inat_id, obs_id| report_one(inat_id, obs_id) }
    summarize(missing)
  end

  def report_one(inat_id, obs_id)
    obs = Observation.find_by(id: obs_id)
    return say("#{obs_id} no longer in MO") unless obs

    people = engagement(obs)
    native = native?(obs)
    @deletable = @deletable.to_i + 1 if people.empty? && !native
    say(row_for(obs, inat_id, native, people))
  end

  def row_for(obs, inat_id, native, people)
    format(ROW, obs.id, inat_id, obs.when, obs.images.size,
           native ? "YES" : "-", attachments(obs).presence || "-",
           inat_user(obs) || "-", people.presence || "-")
  end

  # A companion that is not itself a reflection holds MO-native content.
  def native?(obs)
    return false unless obs.occurrence

    obs.occurrence.observations.where.not(id: obs.id).
      any? { |other| other.reflected_at.nil? }
  end

  def engagement(obs)
    (typed_namings(obs) + other_comments(obs)).join(" ")
  end

  # A mirrored naming carries external_site; a person typed the rest.
  # Kingdom through Order are placeholders, not identifications.
  def typed_namings(obs)
    typed = obs.namings.select do |naming|
      naming.external_site_id.nil? && naming.user_id != obs.user_id &&
        PLACEHOLDER_RANKS.exclude?(naming.name.rank.to_s)
    end
    typed.map { |n| "#{login(n.user_id)}:#{n.name.text_name}" }
  end

  def other_comments(obs)
    obs.comments.reject { |c| c.user_id == obs.user_id }.
      map { |c| "comment:#{login(c.user_id)}" }
  end

  def attachments(obs)
    { seq: obs.sequences.size, herb: obs.herbarium_records.size,
      slip: obs.field_slip ? 1 : 0, list: obs.species_lists.size }.
      reject { |_key, count| count.zero? }.keys.join(",")
  end

  # The import records the observer's iNat login in the notes, which is
  # how a live replacement can be searched for without guessing at an
  # identity.
  def inat_user(obs)
    obs.notes[:iNat_imported_data].to_s[/^User:\s*(\S+)/, 1]
  end

  def login(user_id) = User.find_by(id: user_id)&.login || user_id

  def summarize(missing)
    say("")
    say("#{missing.size} reflections with no live iNat source; " \
        "#{@deletable || 0} have no MO-native content and no engagement.")
  end

  def say(line)
    puts(line)
    @lines << line
  end

  def write_report
    FileUtils.mkdir_p(File.dirname(@out_path))
    File.write(@out_path, "#{@lines.join("\n")}\n")
    warn("Report written to #{@out_path}")
  end
end

OrphanedReflections.new(
  ARGV[0] || "projects/inat-sync/orphaned_reflections.txt"
).run
