# frozen_string_literal: true

# miscellaneous helpers for parameter parsing, location validation
class API
  def parse_names_parameters
    args = {
      names: parse_array(:name, :name, as: :verbatim),
      include_synonyms: parse(:boolean, :include_synonyms),
      include_subtaxa: parse(:boolean, :include_subtaxa)
    }
    if (names = parse_array(:name, :synonyms_of, as: :id))
      args[:names]            = names
      args[:include_synonyms] = true
    end
    if (names = parse_array(:name, :children_of, as: :id))
      args[:names]           = names
      args[:include_subtaxa] = true
      args[:exclude_original_names] = true
    end
    deprecate_parameter(:synonyms_of)
    deprecate_parameter(:children_of)
    args
  end

  def make_sure_location_isnt_dubious!(name)
    return if name.blank? || Location.where(name: name).any?

    citations =
      Location.check_for_empty_name(name) +
      Location.check_for_dubious_commas(name) +
      Location.check_for_bad_country_or_state(name) +
      Location.check_for_bad_terms(name) +
      Location.check_for_bad_chars(name)
    return if citations.none?

    raise(DubiousLocationName.new(citations))
  end

  def parse_bounding_box!
    n = parse(:latitude, :north, help: 1)
    s = parse(:latitude, :south, help: 1)
    e = parse(:longitude, :east, help: 1)
    w = parse(:longitude, :west, help: 1)
    return if no_edges(n, s, e, w)
    return [n, s, e, w] if all_edges(n, s, e, w)

    raise(NeedAllFourEdges.new)
  end

  #########

  private

  def no_edges(north, south, east, west)
    !(north || south || east || west)
  end

  def all_edges(north, south, east, west)
    north && south && east && west
  end
end
