# frozen_string_literal: true

class Inat
  # An MO project's constraints as iNat observation-search params
  # (#5416): its target names as taxon ids, its target locations as
  # place ids, the area of its location as a box, and its dates.
  #
  # The mappings are cached per Name and per Location rather than per
  # project, since they are the same wherever the name is targeted and
  # they change only when the record does.
  #
  # A name that resolves to no iNat taxon, or a location to no iNat
  # place, is reported rather than guessed at: the box still constrains
  # the search, and an admin can be told what did not resolve.
  class ConstraintMapper
    include Inat::Constants
    include Inat::JsonFetch

    CACHE_TTL = 30.days

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

    def initialize(project)
      @project = project
      @unresolved_names = []
      @unresolved_locations = []
    end

    attr_reader :unresolved_names, :unresolved_locations

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
      ids = @project.target_names.filter_map { |name| taxon_id_for(name) }
      ids.any? ? ids.join(",") : IMPORTABLE_TAXON_IDS_ARG
    end

    def place_id_param
      ids = @project.target_locations.filter_map { |loc| place_id_for(loc) }
      ids.any? ? ids.join(",") : nil
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
      id = Rails.cache.fetch(["inat_taxon", name.id, name.updated_at],
                             expires_in: CACHE_TTL) do
        text_names_for(name).lazy.filter_map { |text| search_taxon(text) }.first
      end
      @unresolved_names << name.text_name unless id
      id
    end

    def text_names_for(name)
      ([name.text_name] + name.synonyms.map(&:text_name)).
        flat_map { |text| [text, strip_rank_markers(text)] }.uniq
    end

    def strip_rank_markers(text)
      text.gsub(RANK_MARKERS, " ").squeeze(" ").strip
    end

    def search_taxon(text_name)
      results = fetch_json("taxa?q=#{escape(text_name)}&per_page=5")&.
                dig("results") || []
      results.find { |taxon| taxon["name"].to_s.casecmp?(text_name) }&.
        dig("id")
    end

    # MO writes a location from the inside out, so its first segment is
    # what iNat calls the place: "Barnstable Co., Massachusetts, USA"
    # searches for "Barnstable Co.".
    def place_id_for(location)
      id = Rails.cache.fetch(["inat_place", location.id, location.updated_at],
                             expires_in: CACHE_TTL) do
        search_place(location)
      end
      @unresolved_locations << location.name unless id
      id
    end

    def search_place(location)
      queries = place_queries(location)
      return nil if queries.empty?

      queries.lazy.
        filter_map { |query| matching_place(query, queries, location) }.first
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
      place_candidates(query).find do |place|
        spellings.any? { |name| place["name"].to_s.casecmp?(name) } &&
          overlaps?(place, location)
      end&.dig("id")
    end

    def place_candidates(query)
      fetch_json("places/autocomplete?q=#{escape(query)}")&.
        dig("results") || []
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

      Array(geojson["coordinates"]).flatten(2).
        select { |point| point.is_a?(Array) && point.size >= 2 }.
        map { |point| [point.first.to_f, point.last.to_f] }
    end
  end
end
