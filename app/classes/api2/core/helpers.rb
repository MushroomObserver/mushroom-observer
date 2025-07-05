# frozen_string_literal: true

# miscellaneous helpers for parameter parsing, location validation
module API2::Helpers
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
    put_names_and_modifiers_in_hash(args)
  end

  def put_names_and_modifiers_in_hash(args)
    modifiers = [:include_subtaxa, :include_synonyms,
                 :include_immediate_subtaxa, :exclude_original_names]
    lookup, include_subtaxa, include_synonyms,
    include_immediate_subtaxa, exclude_original_names =
      args.values_at(:names, *modifiers)
    names = { lookup:, include_subtaxa:, include_synonyms:,
              include_immediate_subtaxa:, exclude_original_names: }
    return {} if names.compact.blank?

    args[:names] = names.compact
    args.except!(*modifiers)
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

    raise(API2::DubiousLocationName.new(citations))
  end

  def parse_bounding_box!
    north = parse(:latitude, :north, help: 1)
    south = parse(:latitude, :south, help: 1)
    east = parse(:longitude, :east, help: 1)
    west = parse(:longitude, :west, help: 1)
    return if no_edges?(north, south, east, west)

    unless all_edges?(north, south, east, west)
      raise(API2::NeedAllFourEdges.new)
    end

    box = Mappable::Box.new(north:, south:, east:, west:)
    return box.attributes.symbolize_keys if box.valid?

    raise(API2::NeedAllFourEdges.new)
  end

  #########

  private

  def no_edges?(north, south, east, west)
    !(north || south || east || west)
  end

  def all_edges?(north, south, east, west)
    north && south && east && west
  end
end
