# frozen_string_literal: true

# Superform component for rendering faceted search forms.
# Replaces shared/search_form.erb and shared/search_panel.erb partials.
#
# Uses the Query model (e.g., Query::Observations) directly as the form model.
# Field layout is determined by FIELD_COLUMNS on the controller.
# Field types are determined by SearchFieldUI.
#
# @example Usage in ERB
#   <%= render(Components::SearchForm.new(
#         @search,
#         search_controller: self,
#         local: false
#       )) %>
#
# rubocop:disable Metrics/ClassLength
class Components::SearchForm < Components::ApplicationForm
  include ApplicationForm::AutocompleterPrefill

  register_output_helper :search_bar_toggle

  # Boolean select option styles
  BOOL_OPTIONS = {
    nil_yes: [["", ""], ["true", "yes"]],
    nil_boolean: [["", ""], ["true", "yes"], ["false", "no"]]
  }.freeze

  # Additional wrapper options for search-specific fields
  SEARCH_WRAPPER_OPTIONS = [:selected, :between].freeze

  # NOTE: Using regular initialization instead of Literal props because
  # Superform::Rails::Form has its own initialization pattern
  # @param search [Query] the query model
  # @param search_controller [Object] controller with FIELD_COLUMNS
  # @param local [Boolean] if true, don't render header
  # @param action [String] optional explicit form action URL
  attr_reader :form_action_url

  def initialize(search, search_controller:, local: true, form_action_url: nil,
                 **)
    @search_controller = search_controller
    @local = local
    @form_action_url = form_action_url
    super(search, **)
  end

  def view_template
    render_header unless @local
    div(id: "search_#{search_type}_flash") # turbo_stream update target
    render_form_columns
    render_form_buttons
  end

  private

  # Form configuration

  def form_tag(&block)
    form(action: form_action, method: :post, **form_attributes, &block)
  end

  def form_action
    @form_action_url || view_context.url_for(action: :create)
  end

  def form_attributes
    attrs = {
      id: "#{search_type}_search_form",
      class: "faceted-search-form pb-4",
      data: {
        controller: "search-length-validator",
        search_length_validator_max_length_value:
          Searchable::MAX_SEARCH_INPUT_LENGTH,
        search_length_validator_search_type_value: search_type
      }
    }
    attrs[:data].merge!(turbo_stream_data) unless @local
    attrs
  end

  # When not local (nav dropdown), use turbo_stream for in-place updates.
  # When local (search page), #search_nav_form doesn't exist, so skip it.
  def turbo_stream_data
    { turbo_stream: "true" }
  end

  # Delegate to controller for search configuration

  def field_columns
    @field_columns ||= @search_controller.class::FIELD_COLUMNS
  end

  def search_type
    @search_controller.search_type
  end

  # Header (shown when not local/inline)

  def render_header
    div(class: "navbar-flex w-100") do
      div(class: "font-weight-bold h5 text-larger") do
        plain(:search_form_title.t(type: search_type.to_s.upcase.to_sym))
      end
      render_search_bar_toggle
    end
  end

  def render_search_bar_toggle
    search_bar_toggle
  end

  # Form layout

  def render_form_columns
    div(class: "row") do
      field_columns.each do |panels|
        div(class: "col-xs-12 col-md-6") do
          panels.each do |heading, sections|
            render_panel(heading:, sections:)
          end
        end
      end
    end
  end

  def render_panel(heading:, sections:)
    collapsible = sections[:collapsed].present?
    collapse_target = collapsible ? panel_collapse_target(heading) : nil
    expanded = collapsible ? panel_open?(sections:) : false

    render(Components::Panel.new(
             collapsible:, collapse_target:, expanded:
           )) do |panel|
      panel.with_heading { :"search_term_group_#{heading}".l }
      panel.with_body do
        render_shown_fields(sections:)
      end
      if collapsible
        panel.with_body(collapse: true) do
          render_collapsed_fields(sections:)
        end
      end
    end
  end

  def render_shown_fields(sections:)
    return unless sections.is_a?(Hash) && sections[:shown].present?

    sections[:shown].each do |field_spec|
      render_field_row(field_spec:)
    end
  end

  def render_collapsed_fields(sections:)
    return unless sections.is_a?(Hash) && sections[:collapsed].present?

    sections[:collapsed].each do |field_spec|
      render_field_row(field_spec:)
    end
  end

  def panel_collapse_target(heading)
    "##{search_type}_#{heading}"
  end

  def panel_open?(sections:)
    current = search_params&.keys || []
    this_section = sections[:collapsed].flatten
    current.intersect?(this_section)
  end

  def search_params
    model.attributes.compact.transform_keys(&:to_sym)
  end

  # Field rendering

  def render_field_row(field_spec:)
    if field_spec.is_a?(Array)
      div(class: "row") do
        field_spec.each do |subfield|
          div(class: column_classes) do
            render_search_field(field_name: subfield)
          end
        end
      end
    else
      render_search_field(field_name: field_spec)
    end
  end

  def render_search_field(field_name:)
    field_type = SearchFieldUI.for(controller: @search_controller,
                                   field: field_name)
    return unless field_type

    send("render_#{field_type}", field_name:)
  end

  def column_classes
    "col-xs-12 col-sm-6 col-md-12 col-lg-6"
  end

  # Helper to check if a field is a date field
  def date_field?(field_name)
    [:date, :created_at, :updated_at].include?(field_name)
  end

  # Field type renderers
  # Each method renders a specific field type using ApplicationForm methods

  def render_text_field_with_label(field_name:)
    value = if date_field?(field_name)
              date_field_value(field_name)
            else
              field_value(field_name)
            end
    text_field(field_name,
               label: field_label(field_name),
               help: field_help(field_name),
               value: value)
  end

  def render_textarea_field_with_label(field_name:)
    value = array_to_newlines(field_value(field_name))
    text_field(field_name,
               textarea: true,
               rows: 1,
               label: field_label(field_name),
               help: field_help(field_name),
               value: value)
  end

  def render_select_nil_yes(field_name:)
    render_boolean_select(field_name:, style: :nil_yes)
  end

  def render_select_nil_boolean(field_name:)
    render_boolean_select(field_name:, style: :nil_boolean)
  end

  def render_boolean_select(field_name:, style:)
    select_field(field_name, BOOL_OPTIONS[style],
                 label: field_label(field_name),
                 help: field_help(field_name),
                 inline: true,
                 selected: bool_to_string(field_value(field_name)))
  end

  def render_select_misspellings(field_name:)
    # Superform uses [value, label] order (opposite of Rails)
    # Valid values from query_attr: [:no, :include, :only]
    options = [%w[no no], %w[include include], %w[only only]]
    select_field(field_name, options,
                 label: field_label(field_name),
                 help: field_help(field_name),
                 inline: true,
                 selected: field_value(field_name)&.to_s)
  end

  def render_select_rank_range(field_name:)
    options = [nil] + Name.all_ranks
    value, range_value = sorted_rank_range(field_value(field_name))

    render(ApplicationForm::SelectRangeField.new(
             form: self, field_name:, options:,
             value:, range_value:,
             label: field_label(field_name),
             help: field_help(field_name)
           ))
  end

  # Sort rank range values to [low, high] order for display.
  # If one value is blank, substitute the minimum or maximum rank.
  def sorted_rank_range(range)
    return [nil, nil] if range.blank?

    values = range.reject { |v| v.to_s.blank? }
    return [nil, nil] if values.empty?

    sorted = values.sort_by { |v| Name.all_ranks.index(v.to_s) || 0 }
    fill_single_value_range(range, sorted, Name.all_ranks)
  end

  # When only one value provided, fill in min based on which was blank.
  # If first is blank, fill with min (range from min to value).
  # If second is blank, leave it nil (exact match on first value).
  def fill_single_value_range(original, sorted, all_values)
    return [sorted.first, sorted.last] if sorted.size > 1

    if original.first.to_s.blank?
      [all_values.first, sorted.first]
    else
      [sorted.first, nil]
    end
  end

  def render_select_confidence_range(field_name:)
    # Superform uses [value, label] - Vote.opinion_menu returns [label, value]
    options = [[nil, ""]] +
              Vote.opinion_menu.map { |label, value| [value, label] }
    value, range_value = sorted_confidence_range(field_value(field_name))

    render(ApplicationForm::SelectRangeField.new(
             form: self, field_name:, options:,
             value:, range_value:,
             label: field_label(field_name),
             help: field_help(field_name)
           ))
  end

  # Sort confidence range values to [low, high] order for display.
  # If first is blank, fill with minimum. If second is blank, leave nil.
  def sorted_confidence_range(range)
    return [nil, nil] if range.blank?

    values = range.reject { |v| v.nil? || v.to_s.blank? }
    return [nil, nil] if values.empty?

    sorted = values.map(&:to_f).sort
    fill_confidence_range(range, sorted)
  end

  # If first is blank, fill with min (range from min to value).
  # If second is blank, keep as single value - scope handles the
  # appropriate range. Single value behavior:
  # - 0.0: Exact match
  # - Positive: Range from (next_lower, value]
  # - Negative: Range from [value, next_higher)
  def fill_confidence_range(original, sorted)
    return [sorted.first, sorted.last] if sorted.size > 1

    if original.first.nil? || original.first.to_s.blank?
      # First dropdown blank, second has value - range from min to that value
      [Vote::MINIMUM_VOTE.to_f, sorted.first]
    else
      # Single value selection - don't fill with max, let scope handle the range
      # Return integer 0 for "No Opinion" to match Vote.opinion_menu
      first_value = sorted.first.zero? ? 0 : sorted.first
      [first_value, nil]
    end
  end

  def render_single_value_autocompleter(field_name:)
    type = autocompleter_type(field_name)
    ids = field_value(field_name)
    autocompleter_field(field_name,
                        type: type,
                        label: field_label(field_name),
                        help: field_help(field_name),
                        value: prefilled_autocompleter_value(ids, type),
                        hidden_value: ids)
  end

  def render_multiple_value_autocompleter(field_name:)
    type = autocompleter_type(field_name)
    ids = field_value(field_name)
    autocompleter_field(field_name,
                        type: type,
                        textarea: true,
                        label: field_label(field_name),
                        help: multiple_help(field_name),
                        value: prefilled_autocompleter_value(ids, type),
                        hidden_value: ids)
  end

  def render_names_fields_for_obs(field_name:) # rubocop:disable Lint/UnusedMethodArgument
    modifiers = [[:include_synonyms, :include_subtaxa],
                 [:include_all_name_proposals, :exclude_consensus]]
    namespace(:names) do |names_ns|
      NamesLookupFieldGroup(names_namespace: names_ns,
                            query: model,
                            modifier_fields: modifiers)
    end
  end

  def render_names_fields_for_names(field_name:) # rubocop:disable Lint/UnusedMethodArgument
    modifiers = [[:include_synonyms, :exclude_original_names],
                 [:include_subtaxa, :include_immediate_subtaxa]]
    namespace(:names) do |names_ns|
      NamesLookupFieldGroup(names_namespace: names_ns,
                            query: model,
                            modifier_fields: modifiers)
    end
  end

  def render_region_with_in_box_fields(field_name:) # rubocop:disable Lint/UnusedMethodArgument
    RegionWithBoxFields(query: model, form_namespace: self)
  end

  # Field helpers

  def field_label(field_name)
    :"query_#{field_name}".l.humanize
  end

  def field_help(field_name)
    :"#{model.type_tag}_term_#{field_name}".l
  end

  def multiple_help(field_name)
    [field_help(field_name), :form_search_terms_multiple.l].join(" ")
  end

  def field_value(field_name)
    model.send(field_name)
  end

  # Date/time fields may be stored as arrays (e.g., ["2021-01-06-00-00-00"])
  # Join with "-" for display in text input
  def date_field_value(field_name)
    value = field_value(field_name)
    return value unless value.is_a?(Array)

    value.join("-")
  end

  # Convert boolean values to strings for select options
  def bool_to_string(val)
    case val
    when true then "true"
    when false then "false"
    else ""
    end
  end

  # Convert array values to newline-separated string for textarea display
  def array_to_newlines(val)
    return val unless val.is_a?(Array)

    val.join("\n")
  end

  # Form buttons

  def render_form_buttons
    div(class: "text-center") do
      submit(:SEARCH.l, class: "d-inline-block mx-3")
      render_clear_button
    end
  end

  def render_clear_button
    data_attrs = @local ? {} : turbo_stream_data
    a(href: clear_url,
      class: "btn btn-default d-inline-block mx-3 clear-button",
      data: data_attrs) do
      :CLEAR.l
    end
  end

  def clear_url
    if @form_action_url
      # Derive clear URL from action URL (replace /search with /search/new)
      "#{@form_action_url.sub(%r{/search$}, "/search/new")}?clear=true"
    else
      view_context.url_for(action: :new, clear: true)
    end
  end
end
# rubocop:enable Metrics/ClassLength
