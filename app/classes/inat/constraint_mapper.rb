# frozen_string_literal: true

class Inat
  # An MO project's constraints as iNat observation-search params
  # (#5416): its target names as taxon ids, its target locations as
  # place ids, the area of its location as a box, and its dates.
  #
  # The mappings are saved per Name and per Location rather than per
  # project, since they are the same wherever the name is targeted.
  # `InatTargetLookup` holds them and decides when one has gone stale.
  #
  # A name that resolves to no iNat taxon, or a location to no iNat
  # place, is reported rather than guessed at: the box still constrains
  # the search, and an admin can be told what did not resolve.
  #
  # A project can have hundreds of target names, more than iNat's rate
  # limit allows at once. So pages, imports and alerts read only saved
  # lookups, and `InatTargetLookupJob` gets them (`look_up: true`),
  # pacing itself and stopping when iNat refuses one. A target with no
  # saved lookup is neither searched for nor reported as unknown.
  class ConstraintMapper
    include Inat::Constants

    # look_up: send iNat a lookup for each target with no saved one.
    # pace: seconds to wait between lookups.
    # The block is called after each lookup iNat answered.
    def initialize(project, look_up: false, pace: 0, &on_answer)
      @project = project
      @look_up = look_up
      @on_answer = on_answer
      @search = Inat::TargetSearch.new(pace: pace)
      @unresolved_names = []
      @unresolved_locations = []
      @unchecked_count = 0
      @new_answers = 0
    end

    # new_answers is how many lookups iNat answered for this mapper.
    attr_reader :unresolved_names, :unresolved_locations, :new_answers

    # Resolves every target, so the counts below cover them all.
    def look_up_targets
      target_taxa
      target_place_ids
      self
    end

    # How many targets have no saved lookup.
    def unchecked_count
      look_up_targets
      @unchecked_count
    end

    # False when some targets have no saved lookup, so the taxa and
    # places are only part of what the project targets.
    def complete?
      unchecked_count.zero?
    end

    # True when iNat refused a lookup, so the rest were not sent.
    delegate :refused?, to: :@search

    def target_count
      @project.target_names.size + @project.target_locations.size
    end

    def looked_up_count
      target_count - unchecked_count
    end

    # The iNat taxa the project's target names resolve to. Empty when
    # none of them do -- which is different from the search's
    # fungi-wide fallback, and why the alert cycle reads this rather
    # than `params`.
    def target_taxon_ids
      target_taxa.keys
    end

    # iNat taxon id => the MO name targeted through it, which is the
    # name an alert reports: MO may know the taxon under a synonym iNat
    # does not prefer, and a coordinator watches the spelling they
    # entered.
    def target_taxa
      @target_taxa ||=
        @project.target_names.filter_map do |name|
          id = taxon_id_for(name)
          [id, name.text_name] if id
        end.to_h
    end

    # iNat params for everything the project constrains. Empty when it
    # constrains nothing.
    def params
      return {} unless @project.constraints?

      { taxon_id: taxon_id_param, place_id: place_id_param }.
        merge(box_params).merge(date_params).compact
    end

    private

    # Target names when they resolve, and the fungi-and-slime-moulds
    # filter MO applies to every import otherwise.
    def taxon_id_param
      ids = target_taxon_ids
      ids.any? ? ids.join(",") : IMPORTABLE_TAXON_IDS_ARG
    end

    def place_id_param
      ids = target_place_ids
      ids.any? ? ids.join(",") : nil
    end

    # Memoized like target_taxa, so a second call to params neither
    # spends more lookups nor counts a target twice.
    def target_place_ids
      @target_place_ids ||=
        @project.target_locations.filter_map { |loc| place_id_for(loc) }
    end

    def box_params
      box = @project.location
      return {} unless box

      { swlat: box.south, swlng: box.west,
        nelat: box.north, nelng: box.east }
    end

    def date_params
      { d1: @project.start_date, d2: @project.end_date }.compact
    end

    def taxon_id_for(name)
      record_outcome(saved_answer(name), @unresolved_names, name.text_name)
    end

    def place_id_for(location)
      record_outcome(saved_answer(location), @unresolved_locations,
                     location.name)
    end

    # The iNat id, or false when iNat answered with no match. nil when
    # there is no saved answer and none was looked up, and when iNat was
    # asked and did not answer -- an unanswered question is not saved,
    # so the next pass asks it again.
    def saved_answer(target)
      version = Inat::TargetSearch.matching_version(target)
      saved = InatTargetLookup.answer_for(target, version: version)
      return saved unless @look_up && saved.nil?

      answer = @search.answer_for(target)
      return nil if answer.nil?

      InatTargetLookup.record(target, answer, version: version)
      note_answer
      answer
    end

    def note_answer
      @new_answers += 1
      @on_answer&.call(self)
    end

    def record_outcome(id, unresolved, label)
      unresolved << label if id == false
      @unchecked_count += 1 if id.nil?
      id || nil
    end
  end
end
