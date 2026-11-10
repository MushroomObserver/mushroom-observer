# frozen_string_literal: true

# One-time repair: observations on a project's field slip dated or
# placed outside the project, mostly entered after the event with the
# form's defaults. Each takes the earliest in-range date and the largest
# in-area location among its slip's other observations, else the
# project's nearer end date (its last day, after an event) and location.
# Reflections mirror iNat and are left alone.
#
#   bin/rails runner script/repair_slip_observation_dates_locations.rb
#   bin/rails runner script/repair_slip_observation_dates_locations.rb \
#     --apply

APPLY = ARGV.delete("--apply") ? true : false
if ARGV.any?
  warn("Unknown argument(s): #{ARGV.join(", ")}")
  warn("Usage: bin/rails runner " \
       "script/repair_slip_observation_dates_locations.rb [--apply]")
  exit(1)
end

# Moves a slip's out-of-project observations onto its other members'
# date and location.
class SlipObservationRepair
  REPORT_EVERY = 500
  GPS_FIELDS = %w[lat lng alt gps_hidden].freeze

  def initialize(apply:)
    @apply = apply
    @tally = Hash.new(0)
    @started = Time.zone.now
  end

  def run
    puts(@apply ? "APPLYING changes." : "DRY RUN.")
    slips = FieldSlip.where.not(project_id: nil).joins(:occurrence).
            includes(:project, occurrence: { observations: :location })
    total = slips.size
    slips.each_with_index do |slip, index|
      repair_slip(slip)
      progress(index + 1, total)
    end
    summarize
  end

  private

  def repair_slip(slip)
    project = slip.project
    return unless project.location || project.start_date || project.end_date

    plans(project, slip.occurrence.observations.to_a).
      each { |obs, (updates, notes)| repair(slip, obs, updates, notes) }
  end

  # Every plan is made before any write, so a member repaired first is
  # not taken as the source for the next.
  def plans(project, members)
    members.select { |obs| outside?(project, obs) }.
      map { |obs| [obs, plan(project, obs, members - [obs])] }
  end

  def outside?(project, obs)
    project.violates_date_range?(obs) || project.violates_location?(obs)
  end

  # [attributes to write, notes]
  def plan(project, obs, siblings)
    return [{}, ["skipped: reflection of iNat"]] if obs.reflection?

    date, date_note = new_date(project, obs, siblings)
    place, place_note = new_place(project, obs, siblings)
    [place.merge(date ? { when: date } : {}), [date_note, place_note].compact]
  end

  def repair(slip, obs, updates, notes)
    report(slip, obs, notes)
    return unless @apply && updates.any?

    obs.update!(updates)
    join_project(slip, obs)
  rescue ActiveRecord::RecordInvalid => e
    report(slip, obs, ["failed: #{e.message}"])
  end

  # [date or nil, note or nil]
  def new_date(project, obs, siblings)
    return [nil, nil] unless project.violates_date_range?(obs)

    dates = siblings.map(&:when).select { |day| project.covers_date?(day) }
    return [dates.min, "date -> #{dates.min} (sibling)"] if dates.any?

    day = project.nearest_covered_date(obs.when)
    [day, "date -> #{day} (project)"]
  end

  # [attributes, note or nil]
  def new_place(project, obs, siblings)
    return [{}, nil] unless project.violates_location?(obs)

    source = largest_in_area(project, siblings)
    return sibling_place(source) if source

    fallback_place(project, obs)
  end

  def largest_in_area(project, siblings)
    siblings.reject { |sib| project.violates_location?(sib) }.
      max_by { |sib| sib.location&.box_area.to_f }
  end

  def fallback_place(project, obs)
    return [{}, "location: no source"] unless project.location
    return gps_cleared if location_in_area?(project, obs)

    project_place(project)
  end

  # The Location is at the event and only the GPS (a phone fix taken
  # where the observation was entered) is outside, so the GPS goes.
  def location_in_area?(project, obs)
    loc = obs.location
    loc && project.location.contains?(loc.north, loc.west) &&
      project.location.contains?(loc.south, loc.east)
  end

  def gps_cleared
    [{ lat: nil, lng: nil, alt: nil }, "location: kept, GPS cleared (gps)"]
  end

  # The sibling's GPS comes too: found_here? reads GPS first, and the
  # old GPS is what put the observation outside.
  def sibling_place(source)
    attrs = { location_id: source.location_id, where: source.where }.
            merge(source.attributes.slice(*GPS_FIELDS).symbolize_keys)
    [attrs, "location -> #{source.location_id} #{source.where} " \
            "(sibling #{source.id})"]
  end

  def project_place(project)
    attrs = { location_id: project.location_id,
              where: project.location.name, lat: nil, lng: nil, alt: nil }
    [attrs, "location -> #{project.location_id} #{project.location.name} " \
            "(project)"]
  end

  # The slip names the project, so an observation that now satisfies its
  # constraints joins it.
  def join_project(slip, obs)
    project = slip.project
    obs.reload
    return if project.violates_constraints?(obs)
    return if project.observations.exists?(obs.id)

    project.add_observation(obs)
    @tally["joined project"] += 1
  end

  def report(slip, obs, notes)
    notes.each { |note| @tally[note.sub(/ -> .*\((\w+).*\)/, ' from \1')] += 1 }
    puts("#{slip.code} (project #{slip.project_id}) obs #{obs.id} " \
         "user #{obs.user_id} #{obs.when} loc #{obs.location_id}: " \
         "#{notes.join("; ")}")
  end

  def progress(done, total)
    return unless (done % REPORT_EVERY).zero? || done == total

    elapsed = (Time.zone.now - @started).round
    warn("#{done}/#{total} slips, #{elapsed}s")
  end

  def summarize
    puts("\nSummary:")
    @tally.sort.each { |outcome, count| puts("  #{count} #{outcome}") }
    return if @apply

    puts("Dry run - nothing written. To apply: bin/rails runner " \
         "script/repair_slip_observation_dates_locations.rb --apply")
  end
end

SlipObservationRepair.new(apply: APPLY).run
