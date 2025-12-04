# frozen_string_literal: true

# Composite component for the names lookup field with conditional modifier
# checkboxes. Used in search forms for both Name and Observation searches.
#
# Renders a textarea autocompleter for name lookup, plus conditional rows
# of checkbox modifiers that appear when the autocompleter has a value.
#
# @example Usage in SearchForm
#   namespace(:names) do |names_ns|
#     NamesLookupFieldGroup(
#       names_namespace: names_ns,
#       query: model,
#       modifier_fields: [[:include_synonyms, :include_subtaxa], ...]
#     )
#   end
class Components::NamesLookupFieldGroup < Components::Base
  include Phlex::Rails::Helpers::ClassNames
  include Components::ApplicationForm::AutocompleterPrefill

  prop :names_namespace, _Any
  prop :query, Query
  prop :modifier_fields, _Array(Object)

  def view_template
    render_lookup_autocompleter do
      render_conditional_collapse
    end
  end

  private

  def render_lookup_autocompleter(&block)
    field_component = @names_namespace.field(:lookup).autocompleter(
      type: :name,
      textarea: true,
      wrapper_options: {
        label: :NAMES.l,
        help: field_help
      },
      value: prefilled_lookup_value,
      hidden_value: prefilled_lookup_ids
    )
    render(field_component, &block)
  end

  def field_help
    :form_search_terms_multiple.l
  end

  def prefilled_lookup_value
    names = @query.names
    return nil unless names.is_a?(Hash)

    values = names[:lookup]
    return values unless values.is_a?(Array)

    prefill_string_values(values, :name)
  end

  # Returns IDs for hidden field, joined by newlines (textarea separator)
  def prefilled_lookup_ids
    names = @query.names
    return nil unless names.is_a?(Hash)

    values = names[:lookup]
    return nil unless values.is_a?(Array)

    # Filter to only include integer IDs (not string names)
    ids = values.select { |v| v.is_a?(Integer) || v.to_s.match?(/\A\d+\z/) }
    return nil if ids.empty?

    ids.join("\n")
  end

  # Override to use display_name for names (includes formatting)
  def prefill_via_id(val, _type)
    Name.find(val.to_i).display_name
  rescue ActiveRecord::RecordNotFound
    val
  end

  def render_conditional_collapse
    div(data: { autocompleter_target: "collapseFields" },
        class: class_names("collapse", collapse_class)) do
      render_modifier_rows
    end
  end

  def collapse_class
    # Show expanded if lookup has a value OR any modifier has a value
    "in" if lookup_has_value? || modifiers_have_values?
  end

  def lookup_has_value?
    names = @query.names
    return false unless names.is_a?(Hash)

    names[:lookup].present?
  end

  def modifiers_have_values?
    names = @query.names
    return false unless names.is_a?(Hash)

    flat_modifiers = @modifier_fields.flatten
    names.slice(*flat_modifiers).compact.present?
  end

  def render_modifier_rows
    @modifier_fields.each do |field_pair|
      if field_pair.is_a?(Array)
        render_modifier_row(field_pair)
      else
        render_select_field(field_pair)
      end
    end
  end

  def render_modifier_row(fields)
    div(class: "row") do
      fields.each do |field_name|
        div(class: column_classes) do
          render_select_field(field_name)
        end
      end
    end
  end

  def render_select_field(field_name)
    # Superform uses [value, label] order (opposite of Rails)
    # Use string "true" instead of boolean true for proper HTML rendering
    options = [["", "no"], ["true", "yes"]]
    field_component = @names_namespace.field(field_name).select(
      options,
      wrapper_options: {
        label: field_label(field_name),
        inline: true
      },
      selected: bool_to_string(field_selected_value(field_name))
    )
    render(field_component)
  end

  def field_label(field_name)
    :"query_#{field_name}".l.humanize
  end

  def field_selected_value(field_name)
    names = @query.names
    return nil unless names.is_a?(Hash)

    names[field_name]
  end

  # Convert boolean values to strings for select options
  def bool_to_string(val)
    case val
    when true then "true"
    when false then "false"
    else ""
    end
  end

  def column_classes
    "col-xs-12 col-sm-6 col-md-12 col-lg-6"
  end
end
