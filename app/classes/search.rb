# frozen_string_literal: true

# Non-AR model for the faceted search form. Subclass this for each model
# you want to search, named after the model it's for, eg "Search::Observations"
class Search
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Search attributes map to query attributes, but contain info for the form:
  # field name, input type, resource type (for autocompleters, defaults to nil)
  search_attr(:pattern, :text)

  UNUSABLE_PARAMETERS = [
    :description_query,
    :image_query,
    :location_query,
    :name_query,
    :observation_query,
    :sequence_query,
    :id_in_set,
    :target,
    :type,
    :search_content,
    :search_name,
    :search_where,
    :search_user,
    :preference_filter # pseudo param indicating user content filter applied
  ].freeze

  # Search attributes are assigned input types depending on the way the
  # corresponding Query attribute is defined. Most use text inputs.
  def self.assign_attributes(query_class)
    query_class.attribute_types.except(*UNUSABLE_PARAMETERS).
      each do |attr_name, definition|
      values = definition.accepts
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
      search_attr(attr_name, :multiple_value_autocompleter, values[0]&.type_tag)
    else
      search_attr(attr_name, :text)
    end
  end

  # The hash is very flexible. This covers current uses:
  def self.assign_hash_attribute(attr_name, values)
    case values.first[0]
    when :lookup
      search_attr(attr_name, :multiple_value_autocompleter, :name)
    when :boolean
      search_attr(attr_name, :checkbox)
    when :north
      search_attr(attr_name, :box_input)
    when :string # literally this symbol, not "any string".
      search_attr(attr_name, :no_either_only_select)
    else
      search_attr(attr_name, :text)
    end
  end

  # Returns the type of search (table_name) the subclass filter is for.
  def self.search_type
    name.pluralize.underscore.to_sym
  end
end
