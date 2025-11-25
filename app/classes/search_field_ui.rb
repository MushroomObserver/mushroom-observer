# frozen_string_literal: true

# Service object to determine which UI component to use for a search field.
# Extracts UI selection logic from the Searchable concern.
#
# @example Usage in controller
#   SearchFieldUI.for(controller: self, field: :names)
#   # => :names_fields_for_obs
#
# @example With instance
#   SearchFieldUI.new(controller: self, field: :has_images).ui_type
#   # => :select_nil_boolean
class SearchFieldUI
  attr_reader :controller, :field

  def initialize(controller:, field:)
    @controller = controller
    @field = field
  end

  # Class method for cleaner syntax
  # @param controller [ApplicationController] the search controller instance
  # @param field [Symbol] the field name to determine UI for
  # @return [Symbol] the UI component type
  def self.for(controller:, field:)
    new(controller: controller, field: field).ui_type
  end

  # Determines the UI component type for the field
  # @return [Symbol] the UI component type
  # @raise [RuntimeError] if field is not defined in controller params
  def ui_type
    validate_field_defined!
    determine_ui
  end

  private

  def validate_field_defined!
    defined = permitted_params + nested_params
    return if defined.include?(field)

    raise("Search field not permitted: #{field} " \
          "in #{module_name}::SearchController")
  end

  def determine_ui
    # Handle exceptions first
    case field
    when :names then names_field_ui
    when :lookup then :multiple_value_autocompleter
    when :include_synonyms, :include_subtaxa,
         :include_immediate_subtaxa, :exclude_original_names,
         :exclude_consensus, :include_all_name_proposals,
         :misspellings, :rank, :confidence
      custom_select_ui
    when :region then region_field_ui
    when :in_box then :in_box_fields
    when :field_slips then :text_field_with_label
    else
      field_ui_from_query_attribute
    end
  end

  def custom_select_ui
    case field
    when :include_synonyms, :include_subtaxa,
         :include_immediate_subtaxa, :exclude_original_names,
         :exclude_consensus, :include_all_name_proposals
      :select_no_eq_nil_or_yes
    when :misspellings then :select_misspellings
    when :rank then :select_rank_range
    when :confidence then :select_confidence_range
    end
  end

  def field_ui_from_query_attribute
    case definition
    when :boolean then :select_nil_boolean
    when :string then :text_field_with_label
    when Array then ui_for_array_definition
    when Class then :single_value_autocompleter
    when Hash then ui_for_hash_definition
    else
      raise(
        "Unhandled query attribute definition (SearchFieldUI) for " \
        "#{field}: #{definition.inspect}"
      )
    end
  end

  # Determines UI for hash-based query attribute definitions
  # @return [Symbol] the UI component type
  def ui_for_hash_definition
    case definition.keys.first.to_sym
    when :boolean then :select_nil_yes
    end
  end

  # Determines UI for array-based query attribute definitions
  # @return [Symbol] the UI component type
  def ui_for_array_definition
    case definition.first
    when :string, :time, :date then :text_field_with_label
    when Class then :multiple_value_autocompleter
    end
  end

  # Returns controller-specific names field UI
  # @return [Symbol] the UI component type
  def names_field_ui
    case search_type
    when :observations, :projects, :species_lists
      :names_fields_for_obs
    when :names
      :names_fields_for_names
    end
  end

  # Returns controller-specific region field UI
  # @return [Symbol] the UI component type
  def region_field_ui
    case search_type
    when :observations, :locations
      :region_with_in_box_fields
    else
      :text_field_with_label
    end
  end

  def module_name
    @module_name ||= controller.class.name.deconstantize
  end

  def search_type
    @search_type ||= module_name.underscore.to_sym
  end

  def query_subclass
    @query_subclass ||= Query.const_get(module_name)
  end

  def permitted_params
    controller.permitted_search_params
  end

  def nested_params
    controller.nested_names_params
  end

  # Memoized query attribute definition for the field
  def definition
    @definition ||= query_subclass.attribute_types[field]&.accepts
  end
end
