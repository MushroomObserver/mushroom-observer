# frozen_string_literal: true

# Standardizes the project and field-slip associations of the
# observations created by one iNat import, against a target project
# (e.g. the 2026 NAMA Yoop project). Idempotent: safe to re-run.
#
#   Dry run (default -- reports what WOULD change, writes nothing):
#     bin/rails runner script/standardize_inat_import_project_slips.rb \
#       <import_id> <project_id>
#   Live run:
#     bin/rails runner script/standardize_inat_import_project_slips.rb \
#       <import_id> <project_id> --apply
#
# For each imported observation, in priority order:
#
#   1. iNat-linked native partner. A native (non-import) observation whose
#      notes cite this observation's iNat number, and which carries a
#      field slip, is the same physical specimen scanned during the foray
#      -- its slip (the correct-year one) wins. The import observation
#      joins that native's occurrence; the native stays primary (an
#      import reflection may not be an occurrence's primary). An import
#      observation that already sits in an occurrence is merged in, so a
#      reused 2025 slip yields to the native's 2026 slip.
#   2. A field slip attached to it, spare or in the wrong project (a
#      reused old slip with no 2026 counterpart). The slip is reassigned
#      to the target project and the observation is added to it.
#   3. A target-prefix slip code sitting in its notes (the collector wrote
#      the code in the iNat description rather than photographing a slip
#      the scanner could read). The slip is attached from that code.
#   4. Nothing. It is simply added to the target project.
#
# Every imported observation ends up a member of the target project.
# `add_observation` files it regardless of the project's location
# constraints (a foray record belongs even if its locality is off); any
# constraint violators are reported so a human can look.
class InatImportProjectSlipStandardizer
  INAT_REF = %r{(?:observations/|iNat[^0-9]{0,4})(\d{6,})}i

  def initialize(import_id:, project_id:, apply:)
    @import = InatImport.find(import_id)
    @project = Project.find(project_id)
    @prefix = @project.field_slip_prefix.to_s
    @apply = apply
    @site = ExternalSite.find_by!(name: "iNaturalist")
    @report = Hash.new { |h, k| h[k] = [] }
    @violators = []
  end

  def run
    obs = @import.observations.includes(:projects, occurrence: :field_slip).to_a
    @inat_by_obs = inat_id_map(obs)
    @native_by_inat = build_native_index(obs)
    obs.each { |o| process(o) }
    print_report(obs.size)
  end

  private

  # Observation id => its iNat number, from the import ExternalLink.
  def inat_id_map(obs)
    ExternalLink.where(target_type: "Observation", target_id: obs.map(&:id),
                       external_site_id: @site.id, relationship: "import").
      pluck(:target_id, :external_id).to_h.transform_values(&:to_s)
  end

  # iNat number => a native (non-import) observation that cites it in its
  # notes AND carries a field slip -- the same-specimen foray record whose
  # slip should win.
  def build_native_index(obs)
    wanted = @inat_by_obs.values.to_set
    import_ids = obs.map(&:id)
    index = {}
    Observation.where("notes LIKE ?", "%iNat%").where.not(id: import_ids).
      includes(occurrence: :field_slip).find_each(batch_size: 500) do |cand|
      index_native(cand, index, wanted)
    end
    index
  end

  def index_native(cand, index, wanted)
    return unless cand.occurrence&.field_slip_id

    cand.notes.to_s.scan(INAT_REF).flatten.uniq.each do |num|
      index[num] ||= cand if wanted.include?(num)
    end
  end

  def process(observation)
    native = @native_by_inat[@inat_by_obs[observation.id]]
    if native
      link_to_native(observation, native)
    elsif (slip = observation.occurrence&.field_slip)
      reassign_slip(observation, slip)
    elsif (code = notes_slip_code(observation))
      attach_from_notes(observation, code)
    else
      add_bare(observation)
    end
  end

  # Case 1: join the native's occurrence; its slip wins.
  def link_to_native(observation, native)
    if observation.occurrence_id == native.occurrence_id
      return note(:already_linked, observation,
                  "native occ #{native.occurrence_id}")
    end

    if observation.occurrence_id
      merge_into_native(observation, native)
    else
      join_native(observation, native)
    end
    ensure_member(observation)
  end

  def merge_into_native(observation, native)
    occ = native.occurrence
    yielded = observation.occurrence.field_slip&.code
    apply { Occurrence.merge!(occ, observation.occurrence, @import.user) }
    note(:merged_into_native, observation,
         "native #{native.id} slip #{occ.field_slip.code} (yields #{yielded})")
  end

  def join_native(observation, native)
    occ = native.occurrence
    apply { observation.update!(occurrence: occ) }
    note(:joined_native, observation,
         "native #{native.id} occ #{occ.id} slip #{occ.field_slip.code}")
  end

  # Case 2: a reused/spare slip with no native counterpart -- move it and
  # the observation into the target project, keeping its (2025) code.
  def reassign_slip(observation, slip)
    if slip.project_id == @project.id && member?(observation)
      return note(:slip_already_set, observation, "slip #{slip.code}")
    end

    # Set the column directly: `FieldSlip#project=` gates on the current
    # user's add-slip permission and silently keeps nil for a backfill.
    # The project_id change fires `cascade_project_change`, which files
    # the occurrence's observations into the project.
    apply do
      slip.update!(project_id: @project.id) if slip.project_id != @project.id
    end
    ensure_member(observation)
    note(:reassigned_slip, observation,
         "slip #{slip.code} -> project #{@project.id}")
  end

  # Case 3: attach the slip named by a target-prefix code found in notes.
  def attach_from_notes(observation, code)
    apply do
      FieldSlip::Attacher.attach(observation: observation, code: code,
                                 user: observation.user, join_in_use: true)
      keep_native_primary(observation.reload.occurrence)
    end
    ensure_member(observation)
    note(:attached_from_notes, observation, "code #{code}")
  end

  # An in-use code joins an existing occurrence, and `Attacher` makes the
  # joining observation its primary -- wrong when the joiner is an import
  # reflection and a native member is present, since a reflection may not
  # be an occurrence's primary. Hand primary to the oldest native member;
  # an all-reflection occurrence keeps the reflection primary.
  def keep_native_primary(occurrence)
    return unless occurrence

    occurrence.reload
    return unless occurrence.primary_observation&.reflection?

    native = occurrence.observations.reject(&:reflection?).min_by(&:id)
    occurrence.update!(primary_observation: native) if native
  end

  # Case 4: no slip, no code, no native -- just a project member.
  def add_bare(observation)
    return note(:bare_already_member, observation) if member?(observation)

    ensure_member(observation)
    note(:added_bare, observation, "-> project #{@project.id}")
  end

  # The first target-prefix (#{prefix}-NNNN) code in the observation's
  # notes -- the description/Other part, not the iNat snapshot the
  # scanner already reads.
  def notes_slip_code(observation)
    return nil if @prefix.blank?

    observation.notes.to_s[/\b#{Regexp.escape(@prefix)}-\d{1,6}\b/i]&.upcase
  end

  def member?(observation)
    (observation.projects.loaded? &&
      observation.projects.any? { |p| p.id == @project.id }) ||
      @project.observations.exists?(id: observation.id)
  end

  def ensure_member(observation)
    return if member?(observation)

    @violators << observation.id if @project.violates_constraints?(observation)
    apply { @project.add_observation(observation) }
  end

  def apply
    yield if @apply
  end

  def note(key, observation, detail = nil)
    @report[key] << "#{observation.id}#{" #{detail}" if detail}"
  end

  def print_report(total)
    mode = @apply ? "APPLIED" : "DRY RUN"
    puts("#{mode}: import #{@import.id} -> project #{@project.id} " \
         "#{@project.title.inspect} (prefix #{@prefix.inspect}), #{total} obs")
    print_buckets
    print_violators
    return if @apply

    puts("\nDry run - nothing written. To apply: bin/rails runner " \
         "#{$PROGRAM_NAME} #{@import.id} #{@project.id} --apply")
  end

  def print_buckets
    @report.sort_by { |_k, v| -v.size }.each do |key, ids|
      puts("  #{key}: #{ids.size}")
      ids.first(25).each { |line| puts("      #{line}") }
      puts("      ... (#{ids.size - 25} more)") if ids.size > 25
    end
  end

  def print_violators
    return if @violators.empty?

    puts("  constraint violators force-added: #{@violators.size} " \
         "#{@violators.first(20).inspect}")
  end
end

# ---- argv ----
args = ARGV.dup
apply = args.delete("--apply") ? true : false
unless args.size == 2 && args.all? { |a| a.match?(/\A\d+\z/) }
  abort("Usage: bin/rails runner #{$PROGRAM_NAME} <import_id> " \
        "<project_id> [--apply]")
end

InatImportProjectSlipStandardizer.new(
  import_id: args[0].to_i, project_id: args[1].to_i, apply: apply
).run
