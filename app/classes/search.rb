# frozen_string_literal: true

# Non-AR model for faceted search form input. Don't instantiate this class.
# Usable search classes inherit from this; this class does all the attribute
# assignment automatically. Subclasses just have to be declared.
#
# Search attributes map to query attributes, but contain info for the form:
# field name, input type, resource type (for autocompleters, defaults to nil)
#
# Subclass this for each model
# you want to search, named after the model it's for, eg "Search::Observations"
class Search
  include ActiveModel::Model
  include ActiveModel::Attributes

  UNUSABLE_PARAMETERS = [
    :description_query, # subquery
    :image_query, # subquery
    :location_query, # subquery
    :name_query, # subquery
    :observation_query, # subquery
    :sequence_query, # subquery
    :id_in_set, # ids can just go in :pattern field
    :target, # comment param
    :type, # comment param
    :search_content, # advanced search param
    :search_name, # advanced search param
    :search_where, # advanced search param
    :search_user, # advanced search param
    :preference_filter # pseudo param indicating user content filter applied
  ].freeze

  # All subclasses have a :pattern attribute.
  search_attr(:pattern, :text)

  # Search attributes are assigned input types depending on the way the
  # corresponding Query attribute is defined. Most use text inputs.
  def self.assign_attributes
    query_class.attribute_types.except(*UNUSABLE_PARAMETERS).
      each do |attr_name, definition|
      values = definition.accepts # `accepts` is the Query attribute type def
      case values
      when Symbol
        assign_symbol_attribute(attr_name, values)
      when Array
        assign_array_attribute(attr_name, values)
      when Hash
        assign_hash_attribute(attr_name, values)
      when User
        assign_user_attribute(attr_name, values)
      end
    end
  end

  def self.assign_symbol_attribute(attr_name, values)
    case values
    when :boolean
      search_attr(attr_name, :boolean_select)
    else
      search_attr(attr_name, :text)
    end
  end

  # This covers current uses of arrays:
  def self.assign_array_attribute(attr_name, values)
    case values[0]
    when Class
      search_attr(attr_name, :multiple_value_autocompleter,
                  validates: values[0]&.type_tag)
    else
      search_attr(attr_name, :text)
    end
  end

  # The hash is very flexible. This covers current uses:
  def self.assign_hash_attribute(attr_name, values)
    case values.first[0]
    when :lookup
      search_attr(:names, :lookup_inputs)
      search_attr(:lookup, :multiple_value_autocompleter,
                  validates: :name, nested_under: :names)
      search_attr(:include_synonyms, :boolean_select, nested_under: :names)
      search_attr(:include_subtaxa, :boolean_select, nested_under: :names)
      search_attr(:include_immediate_subtaxa, :boolean_select,
                  nested_under: :names)
      search_attr(:exclude_original_names, :boolean_select,
                  nested_under: :names)
    when :boolean
      search_attr(attr_name, :checkbox)
    when :north
      search_attr(:in_box, :box_inputs)
      search_attr(:north, :text, nested_under: :in_box)
      search_attr(:south, :text, nested_under: :in_box)
      search_attr(:east, :text, nested_under: :in_box)
      search_attr(:west, :text, nested_under: :in_box)
    when :string # literally this symbol, not "any string".
      search_attr(attr_name, :no_either_only_select)
    else
      search_attr(attr_name, :text)
    end
  end

  # Search subclasses should be named the same as Query subclasses.
  def self.query_class
    return if name == "Search"

    klass = "Query::#{name.demodulize}"
    return nil unless Object.const_defined?(klass)

    klass.constantize
  end
  delegate :query_class, to: :class

  # Returns the type of search (table_name) the subclass filter is for.
  def self.search_type
    name.pluralize.underscore.to_sym
  end
  delegate :search_type, to: :class

  # `attribute_types` is a core Rails method, but it unexpectedly returns
  # string keys, and they are not accessible with symbols.
  def self.attribute_types
    super.symbolize_keys!
  end
  delegate :attribute_types, to: :class

  # Same with `attribute_names`
  def self.attribute_names
    super.map!(&:to_sym)
  end
  delegate :attribute_names, to: :class

  # Define has_attribute? here, it doesn't exist yet for ActiveModel.
  def self.has_attribute?(key) # rubocop:disable Naming/PredicatePrefix
    attribute_types.key?(key)
  end
  delegate :has_attribute?, to: :class
end
