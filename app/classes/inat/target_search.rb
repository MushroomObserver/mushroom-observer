# frozen_string_literal: true

class Inat
  # Asks iNaturalist which taxon an MO Name, or which place an MO
  # Location, corresponds to. One target per question, so a project's
  # mapper and a scheduled re-confirmation ask the same way.
  #
  # One instance carries a pass: it paces itself between lookups and
  # stops asking once iNat has refused, since the rest of the pass
  # would be refused too. `Inat::ConstraintMapper` holds one for a
  # project's targets; `InatTargetRefreshJob` holds one for the rows
  # it re-reads.
  #
  # A name that resolves to no iNat taxon, or a location to no iNat
  # place, answers false rather than being guessed at.
  class TargetSearch
    include Inat::Constants
    include Inat::JsonFetch

    # iNat's maximum for place autocomplete.
    PLACE_CANDIDATES = 20

    # Stamped on each saved lookup: a miss is saved too, so changing
    # how targets match, or how a miss is stored, needs a new version
    # to look them up again.
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

    # What iNaturalist says about a taxon id it was given: whether it
    # still treats it as current, and what replaced it when it does not.
    Confirmation = Data.define(:active, :replacement_id)

    # Which matching rules a kind of target is read under, so a saved
    # answer can say which version found it.
    def self.matching_version(target)
      return PLACE_MATCHING_VERSION if target.is_a?(::Location)

      TAXON_MATCHING_VERSION
    end

    # pace: seconds to wait between lookups.
    def initialize(pace: 0)
      @pace = pace
      @lookups = 0
      @inat_failed = false
    end

    # True once iNat refused a lookup, after which nothing more is
    # asked.
    def refused?
      @inat_failed
    end

    # The iNat id for this target, false when iNat answered with no
    # match, or nil when iNat did not answer.
    def answer_for(target)
      return search_place(target) if target.is_a?(::Location)

      search_name(target)
    end

    # What iNaturalist now says about a taxon id MO saved earlier, or
    # nil when it did not answer. Only the taxon itself reports
    # `is_active`: the taxa search returns a deactivated taxon under the
    # name it used to carry, so re-searching gives the same id back.
    #
    # An id iNat has dropped reads as inactive with no replacement. It
    # answers with no results rather than refusing, so that is an answer
    # and not a failure.
    def confirm_taxon(inat_id)
      results = inat_results("taxa/#{inat_id}")
      return nil unless results

      taxon = results.first
      return gone unless taxon

      Confirmation.new(active: taxon["is_active"] != false,
                       replacement_id: replacement_for(taxon))
    end

    # The taxon iNat holds under this id, or nil when it holds none and
    # when it did not answer. A caller adopting the name wants the rank
    # with it, so this is the whole taxon rather than its name.
    def taxon(inat_id)
      inat_results("taxa/#{inat_id}")&.first
    end

    # iNat may know the taxon under a synonym MO does not prefer --
    # Caloboletus peckii is Butyriboletus peckii there -- so the whole
    # synonym group is tried before giving up.
    def search_name(name)
      first_answer(text_names_for(name)) { |text| search_taxon(text) }
    end

    # MO writes a location from the inside out, so its first segment
    # is what iNat calls the place: "Barnstable Co., Massachusetts,
    # USA" searches for "Barnstable Co.".
    def search_place(location)
      queries = place_queries(location)
      first_answer(queries) do |query|
        matching_place(query, queries, location)
      end
    end

    private

    def gone
      Confirmation.new(active: false, replacement_id: nil)
    end

    # A split leaves several outputs and no single replacement, which
    # is not something to adopt on a project's behalf.
    def replacement_for(taxon)
      ids = taxon["current_synonymous_taxon_ids"]
      return nil unless ids.is_a?(Array) && ids.one?

      ids.first
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

    # A same-named place somewhere else is worse than none:
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
