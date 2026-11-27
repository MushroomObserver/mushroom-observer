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
    include Inat::JsonFetch

    # iNat's maximum for place autocomplete.
    PLACE_CANDIDATES = 20

    # Stamped on each saved lookup: a miss is saved too, so changing how
    # targets match, or how a miss is stored, needs a new version to
    # look them up again.
    TAXON_MATCHING_VERSION = 3
    PLACE_MATCHING_VERSION = 4

    # iNat writes an infraspecific name without the rank marker MO
    # uses: MO's "Hygrophorus nemoreus var. raphaneus" is its
    # "Hygrophorus nemoreus raphaneus". The dot is required for the
    # abbreviated markers, so a one-letter word elsewhere in a name is
    # left alone.
    RANK_MARKERS = /\s+(?:var|subvar|subsp|ssp|sect|subg|f|v)\.\s+|
                    \s+(?:forma|form)\s+/xi

    # MO abbreviates a county where iNat writes it out: "Barnstable
    # Co." is iNat's "Barnstable County". Seven of the 57 target
    # locations are written that way.
    COUNTY_ABBREVIATION = /\bCo\.\z/

    # look_up: send iNat a lookup for each target with no saved one.
    # pace: seconds to wait between lookups.
    # The block is called after each lookup iNat answered.
    def initialize(project, look_up: false, pace: 0, &on_answer)
      @project = project
      @look_up = look_up
      @pace = pace
      @on_answer = on_answer
      @unresolved_names = []
      @unresolved_locations = []
      @inat_failed = false
      @lookups = 0
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
    def refused?
      @inat_failed
    end

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

    # iNat may know the taxon under a synonym MO does not prefer --
    # Caloboletus peckii is Butyriboletus peckii there -- so the whole
    # synonym group is tried before giving up.
    def taxon_id_for(name)
      id = saved_answer(name, TAXON_MATCHING_VERSION) do
        first_answer(text_names_for(name)) { |text| search_taxon(text) }
      end
      record_outcome(id, @unresolved_names, name.text_name)
    end

    # The iNat id, or false when iNat answered with no match. nil when
    # there is no saved answer and none was looked up, and when iNat was
    # asked and did not answer -- an unanswered question is not saved,
    # so the next pass asks it again.
    def saved_answer(target, version)
      saved = InatTargetLookup.answer_for(target, version: version)
      return saved unless @look_up && saved.nil?

      answer = yield
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

    # The first match the block finds, false when every call answered
    # with none, or nil when iNat failed before a match was found.
    def first_answer(candidates)
      candidates.each do |candidate|
        answer = yield(candidate)
        return answer unless answer == false
      end
      false
    end

    def text_names_for(name)
      ([name.text_name] + name.synonyms.map(&:text_name)).
        flat_map { |text| [text, strip_rank_markers(text)] }.uniq
    end

    def strip_rank_markers(text)
      text.gsub(RANK_MARKERS, " ").squeeze(" ").strip
    end

    def search_taxon(text_name)
      results = inat_results("taxa?q=#{escape(text_name)}&per_page=5")
      return nil unless results

      results.find do |taxon|
        taxon["name"].to_s.casecmp?(text_name) && importable?(taxon)
      end&.dig("id") || false
    end

    # Some fungal names are also the names of plants or animals, and an
    # import drops a taxon list holding any taxon outside fungi and
    # slime molds.
    def importable?(taxon)
      IMPORTABLE_TAXON_IDS.intersect?(taxon["ancestor_ids"] || [])
    end

    # The results iNat sent, or nil when it was not asked or did not
    # answer.
    def inat_results(path)
      return nil if @inat_failed

      sleep(@pace) if @pace.positive? && @lookups.positive?
      @lookups += 1
      results = fetch_json(path)&.dig("results")
      @inat_failed = true unless results
      results
    end

    # MO writes a location from the inside out, so its first segment is
    # what iNat calls the place: "Barnstable Co., Massachusetts, USA"
    # searches for "Barnstable Co.".
    def place_id_for(location)
      id = saved_answer(location, PLACE_MATCHING_VERSION) do
        search_place(location)
      end
      record_outcome(id, @unresolved_locations, location.name)
    end

    def search_place(location)
      queries = place_queries(location)
      first_answer(queries) { |query| matching_place(query, queries, location) }
    end

    def place_queries(location)
      query = location.name.to_s.split(",").first.to_s.strip
      return [] if query.blank?

      [query, query.sub(COUNTY_ABBREVIATION, "County")].uniq
    end

    # A place answers only to the whole of one of the spellings MO
    # tried, so a fragment match -- "Washington Monument" for
    # "Washington DC" -- is no answer.
    def matching_place(query, spellings, location)
      candidates = place_candidates(query)
      return nil unless candidates

      candidates.find do |place|
        named?(place, spellings) && overlaps?(place, location)
      end&.dig("id") || false
    end

    def named?(place, spellings)
      place_names(place).any? do |place_name|
        spellings.any? { |name| same_place_name?(place_name, name) }
      end
    end

    # iNat spells a place with its diacritics where MO's Location
    # may not: its Quebec is "Québec". Both sides are folded so
    # either spelling answers for the other. A name in a script
    # transliteration cannot carry folds to "?", which would let
    # two unrelated names match, so those compare unfolded.
    def same_place_name?(one, other)
      return true if one.casecmp?(other)

      folded = [one, other].map { |name| fold_diacritics(name) }
      return false if folded.any? { |name| name.include?("?") }

      folded.first.casecmp?(folded.last)
    end

    def fold_diacritics(name)
      ActiveSupport::Inflector.transliterate(name.to_s)
    end

    # iNat names a county by its bare name ("Adams") and spells it out
    # only in the display name ("Adams County, US, PA").
    def place_names(place)
      [place["name"], place["display_name"].to_s.split(",").first].
        compact.map { |name| name.to_s.strip }
    end

    # A common name fills the default ten results with places
    # elsewhere: Adams County, PA is tenth for "Adams County".
    def place_candidates(query)
      inat_results("places/autocomplete?q=#{escape(query)}" \
                   "&per_page=#{PLACE_CANDIDATES}")
    end

    # A same-named place somewhere else is worse than no place at all:
    # searching for Kingston, Rhode Island turns up Kingston, Jamaica.
    # A place iNat gives no box for is accepted, since there is nothing
    # to disagree with.
    def overlaps?(place, location)
      bounds = geojson_bounds(place["bounding_box_geojson"])
      return true unless bounds

      lngs, lats = bounds
      lats.first <= location.north.to_f &&
        lats.last >= location.south.to_f &&
        lngs.first <= location.east.to_f &&
        lngs.last >= location.west.to_f
    end

    # [[min_lng, max_lng], [min_lat, max_lat]] of every point in the
    # polygon, or nil when there is none to read.
    def geojson_bounds(geojson)
      points = coordinate_points(geojson)
      return nil if points.empty?

      [points.map(&:first).minmax, points.map(&:last).minmax]
    end

    def coordinate_points(geojson)
      return [] unless geojson.is_a?(Hash)

      points_in(geojson["coordinates"])
    end

    # A Polygon nests its points one level less deeply than a
    # MultiPolygon, so the depth is found rather than assumed.
    def points_in(node)
      return [] unless node.is_a?(Array)
      return [[node[0].to_f, node[1].to_f]] if point?(node)

      node.flat_map { |child| points_in(child) }
    end

    def point?(node)
      node.size >= 2 && node.first(2).all?(Numeric)
    end
  end
end
