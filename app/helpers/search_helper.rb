# frozen_string_literal: true

# helpers for search forms. These call field helpers in forms_helper.
# args should provide form, field, label at a minimum.
# rubocop:disable Metrics/ModuleLength
module SearchHelper
  # Builds a single filter group, or panel, for a search form. The panel's
  # field groups are defined in the controller, along with the field methods.
  # Sections can be :shown/ :collapsed.
  # If sections[:collapsed] is present, part of the panel will be collapsed.
  def search_panel(form:, search:, heading:, sections:)
    shown = search_panel_shown(form:, search:, sections:)
    collapsed = search_panel_collapsed(form:, search:, sections:)
    open = collapse = false
    if sections[:collapsed].present?
      collapse = heading
      open = search_panel_open?(search:, sections:)
    end
    panel_block(heading: :"search_term_group_#{heading}".l,
                collapse:, open:, collapse_message: :MORE.l,
                panel_bodies: [shown, collapsed])
  end

  # This returns the current search terms in the form of a hash.
  def search_params(search:)
    search.attributes.compact_blank.transform_keys(&:to_sym)
  end

  def search_panel_open?(search:, sections:)
    current = search_params(search:)&.keys || []
    this_section = sections[:collapsed].flatten # could be pairs of fields
    return true if current.intersect?(this_section)

    false
  end

  def search_panel_shown(form:, search:, sections:)
    return unless sections.is_a?(Hash) && sections[:shown].present?

    capture do
      sections[:shown].each do |field|
        concat(search_row(form:, search:, field:, sections:))
      end
    end
  end

  # Content of collapsed section, composed of field rows.
  def search_panel_collapsed(form:, search:, sections:)
    return unless sections.is_a?(Hash) && sections[:collapsed].present?

    capture do
      sections[:collapsed].each do |field|
        concat(search_row(form:, search:, field:, sections:))
      end
    end
  end

  # Fields might be paired, so we need to check for that.
  def search_row(form:, search:, field:, sections:)
    if field.is_a?(Array)
      tag.div(class: "row") do
        field.each do |subfield|
          concat(tag.div(class: search_column_classes) do
            search_field(form:, search:, field: subfield, sections:)
          end)
        end
      end
    else
      search_field(form:, search:, field:, sections:)
    end
  end

  # Figure out what kind of field helper to call, based on definitions below.
  # Some field types need args, so there is both the component and args hash.
  # NOTE: THIS IS WHERE THE ARGS HASH BEGINS TO BE BUILT
  def search_field(form:, search:, field:, sections:)
    args = { form:, search:, field: }

    args[:label] ||= search_label(field)
    field_type = search_field_type_from_controller(field:)
    return unless field_type

    # Prepare args for the field helper.
    args = prepare_args_for_search_field(args:, field_type:)
    args = adjust_args_for_certain_fields(args:, field_type:, sections:)

    send(field_type, **args)
  end

  # The field's label.
  def search_label(field)
    if field == :pattern
      :PATTERN.l
    else
      :"query_#{field}".l.humanize
    end
  end

  # The controllers define how they're going to parse their
  # fields, so we can use that to assign a field helper.
  def search_field_type_from_controller(field:)
    # return :pattern if field == :pattern

    defined = controller.permitted_search_params.
              merge(controller.nested_names_params)
    unless defined[field]
      raise("No input defined for #{field} in #{controller.controller_name}")
    end

    defined[field]
  end

  # Prepares HTML args for the field helper. This is where we can make
  # adjustments to the args hash before passing it to the field helper.
  # NOTE: Bootstrap 3 can't do full-width inline label/field.
  def prepare_args_for_search_field(args:, field_type:)
    if field_type == :text_field_with_label && args[:field] != :pattern
      args[:inline] = true
    end
    args[:help] = search_help_text(args, field_type)
    args[:hidden_name] = search_check_for_hidden_field_name(args)
    # args[:class] = "mb-3"
    search_prefill_or_select_values(args, field_type)
  end

  def adjust_args_for_certain_fields(args:, field_type:, sections:)
    if field_type == :multiple_autocompleter
      args[:type] = if args[:field] == :project_lists
                      :project
                    else
                      args[:field]
                    end
    end
    # readd :sections for conditional fields.
    if search_fields_needing_sections.include?(field_type)
      args = args.merge(sections:)
    end
    # Remove the search object unless we need it (will print otherwise)
    unless search_fields_needing_search_object.include?(field_type)
      args = args.except(:search)
    end

    args
  end

  def search_fields_needing_sections
    [:names_fields_for_names, :names_fields_for_obs].freeze
  end

  def search_fields_needing_search_object
    [:names_fields_for_names, :names_fields_for_obs,
     :multiple_value_autocompleter, :region_with_in_box_fields].freeze
  end

  # TODO: fix this, needs query tags not pattern search term tags
  def search_help_text(args, field_type)
    multiple_note = if field_type == :multiple_autocompleter
                      :pattern_search_terms_multiple.l
                    end
    [:"#{args[:search].type_tag}_term_#{args[:field]}".l,
     multiple_note].compact.join(" ")
  end

  # Overrides for the assumed name of the id field for autocompleter.
  def search_check_for_hidden_field_name(args)
    case args[:field]
    when :list
      return "list_id"
    when :project_lists
      return "project_lists_id"
    end
    nil
  end

  ###############################################################
  #
  # FIELD HELPERS
  #
  def multiple_value_autocompleter(**args)
    # rightward destructuring assignment, Ruby 3 feature
    args => { field:, search: }
    args[:type] = search_autocompleter_type(field)
    args[:separator] = SEARCH_SEPARATOR
    args[:textarea] = true
    args[:hidden_name] = :"#{field}_id"
    args[:hidden_value] = search_attribute_possibly_nested_value(search, field)
    args[:value] = search_autocompleter_prefillable_values(search, field)
    autocompleter_field(**args.except(:search))
  end

  def search_autocompleter_type(field)
    case field
    when :project_lists
      :project
    when :lookup
      :name
    when :by_users
      :user
    else
      field.to_s.singularize.to_sym
    end
  end

  def search_autocompleter_prefillable_values(search, field)
    values = search_attribute_possibly_nested_value(search, field)
    return values unless values.is_a?(Array)

    search_string_values(values, field)
  end

  # For autocompleters, if the value(s) is/are ids, we need to lookup the
  # strings that should be prefilled in the text field — ids go in the
  # "hidden_field" for ids.
  def search_string_values(values, field)
    values.map do |val|
      if val.is_a?(Numeric) ||
         (val.is_a?(String) && val.match(/^-?(\d+(\.\d+)?|\.\d+)$/))
        search_string_via_lookup_id(val, field)
      else
        val
      end
    end.join(SEARCH_SEPARATOR)
  end

  def search_string_via_lookup_id(val, field)
    lookup_name = field.to_s.camelize # already plural
    lookup_name = "Names" if lookup_name == "Lookup"
    lookup = "Lookup::#{lookup_name}".constantize
    title_method = lookup::TITLE_METHOD # this is the attribute we want
    model = lookup_name.singularize.constantize
    model.find(val.to_i).send(title_method)
  end

  def names_fields_for_names(**args)
    args[:sections] = [[:include_synonyms, :exclude_original_names],
                       [:include_subtaxa, :include_immediate_subtaxa]]
    names_fields_for_search(**args)
  end

  def names_fields_for_obs(**args)
    args[:sections] = [[:include_synonyms, :include_subtaxa],
                       [:include_all_name_proposals, :exclude_consensus]]
    names_fields_for_search(**args)
  end

  def names_fields_for_search(**args)
    args[:form].fields_for(:names) do |f_n|
      args = args.merge(form: f_n, field: :lookup, label: :NAMES.l)
      autocompleter_with_conditional_fields(**args)
    end
  end

  # Complex mechanism: append collapsed fields to autocompleter that only appear
  # when autocompleter has a value. Only on names fields, for lookup modifiers.
  def autocompleter_with_conditional_fields(**args)
    return if args[:sections].blank?

    # rightward destructuring assignment, Ruby 3 feature
    args => { form:, search:, sections: }

    # If there are conditional rows that should appear if user input, add these
    append = autocompleter_conditional_rows(form:, search:, sections:)
    multiple_value_autocompleter(append:, **args.except(:sections))
  end

  # Rows that only uncollapse if an autocompleter field has a value.
  # Note the data-autocompleter-target attribute.
  def autocompleter_conditional_rows(form:, search:, sections:)
    tag.div(data: { autocompleter_target: "collapseFields" },
            class: "collapse") do
      sections.each do |subfield|
        concat(search_row(form:, field: subfield, search:, sections:))
      end
    end
  end

  def select_yes(**args)
    options = [
      ["", nil],
      ["yes", true]
    ]
    select_with_label(options:, inline: true, **args)
  end

  def select_boolean(**args)
    options = [
      ["", nil],
      ["yes", true],
      ["no", false]
    ]
    select_with_label(options:, inline: true, **args)
  end

  def select_misspellings(**args)
    options = [
      ["", nil],
      ["yes", :yes],
      ["no", :no],
      ["both", :either]
    ]
    select_with_label(options:, inline: true, **args)
  end

  def select_rank_range(**args)
    options = Name.all_ranks
    [
      tag.div(class: "d-inline-block mr-4") do
        select_with_label(options:,
                          **search_rank_args(args))
      end,
      tag.div(class: "d-inline-block") do
        select_with_label(options:,
                          **search_rank_range_args(args))
      end
    ].safe_join
  end

  # these need to overwrite
  def search_rank_args(args)
    value, _range = args[:selected]
    args.except(:search).merge(
      { include_blank: true, inline: true, selected: value }
    )
  end

  # these need to overwrite
  def search_rank_range_args(args)
    _value, range = args[:selected]
    args.except(:search).merge(
      { field: "#{args[:field]}_range", label: :to.l, selected: range,
        include_blank: true, between: :optional, help: nil, inline: true }
    )
  end

  def select_confidence_range(**args)
    options = Vote.opinion_menu.map { |k, v| [k, Vote.percent(v)] }
    [
      tag.div(class: "d-inline-block mr-4") do
        select_with_label(options:, **search_confidence_args(args))
      end,
      tag.div(class: "d-inline-block") do
        select_with_label(options:, **search_confidence_range_args(args))
      end
    ].safe_join
  end

  # these need to overwrite
  def search_confidence_args(args)
    value, _range = args[:selected]
    args.except(:search).merge(
      { include_blank: true, inline: true, selected: value }
    )
  end

  # these need to overwrite
  def search_confidence_range_args(args)
    _value, range = args[:selected]
    args.except(:search).merge(
      { field: "#{args[:field]}_range", label: :to.l, selected: range,
        include_blank: true, between: :optional, help: nil, inline: true }
    )
  end

  def region_with_in_box_fields(**args)
    tag.div(data: { controller: "map", map_open: true }) do
      [
        form_location_input_find_on_map(form: args[:form], field: :region,
                                        value: args[:search]&.region,
                                        label: "#{:REGION.t}:"),
        in_box_fields(**args)
      ].safe_join
    end
  end

  # currently combined with region for observations form
  def in_box_fields(**args)
    fields_for(:in_box) do |fib|
      search_compass_input_and_map(form: fib, search: args[:search])
    end
  end

  def search_compass_input_and_map(form:, search:)
    minimal_loc = search_minimal_location(search)
    capture do
      [
        form_compass_input_group(form:, obj: minimal_loc),
        search_editable_map(minimal_loc)
      ].safe_join
    end
  end

  def search_editable_map(minimal_loc)
    # capture do
    make_map(objects: [minimal_loc], editable: true, map_type: "location",
             map_open: true, controller: nil)
    # end
  end

  # To be mappable, we need to instantiate a minimal location from the search.
  def search_minimal_location(search)
    if search&.in_box.present?
      box = search.in_box
      args = {
        id: nil, name: nil,
        north: box.north, south: box.south, east: box.east, west: box.west
      }
    else
      args = { id: nil, name: nil, north: 0, south: 0, east: 0, west: 0 }
    end
    Mappable::MinimalLocation.new(**args)
  end

  # def search_longitude_field(**args)
  #   text_field_with_label(
  #     **args.except(:search), between: "(-180.0 to 180.0)"
  #   )
  # end

  # def search_latitude_field(**args)
  #   text_field_with_label(
  #     **args.except(:search), between: "(-90.0 to 90.0)"
  #   )
  # end

  def search_prefill_or_select_values(args, field_type)
    # rightward destructuring assignment, Ruby 3 feature
    args => { field:, search: }
    return args if [:names, :in_box].include?(field)

    value = search_attribute_possibly_nested_value(search, field)

    if SEARCH_SELECT_TYPES.include?(field_type)
      args[:selected] = value
    else
      args[:value] = value
    end
    args
  end

  # Figure out if a field value is nested within the query, so we can access it
  # to prefill nested fields in the form. See note in Searchable.
  def search_attribute_possibly_nested_value(search, field)
    unless controller.nested_field_names.include?(field)
      return search.send(field) # simple accessor of the search Query object
    end

    search.send(:names)&.dig(field) # nested attributes accessed by key
  end

  def search_column_classes
    "col-xs-12 col-sm-6 col-md-12 col-lg-6"
  end

  # Separator for autocompleter fields.
  SEARCH_SEPARATOR = "\n"

  # Convenience for subclasses to access helper methods via subclass.params
  SEARCH_FIELD_HELPERS = {
    text_field: { component: :text_field_with_label, args: {} },
    select_yes: { component: :search_yes_field, args: {} },
    select_boolean: { component: :search_boolean_field, args: {} },
    select_rank_range: { component: :search_rank_range_field, args: {} },
    list_of_herbaria: { component: :autocompleter_field,
                        args: { type: :herbarium,
                                separator: SEARCH_SEPARATOR } },
    list_of_locations: { component: :autocompleter_field,
                         args: { type: :location, separator: "\n" } },
    list_of_names: { component: :search_autocompleter_with_conditional_fields,
                     args: { type: :name, separator: SEARCH_SEPARATOR } },
    list_of_projects: { component: :autocompleter_field,
                        args: { type: :project,
                                separator: SEARCH_SEPARATOR } },
    list_of_species_lists: { component: :autocompleter_field,
                             args: { type: :species_list,
                                     separator: SEARCH_SEPARATOR } },
    list_of_users: { component: :autocompleter_field,
                     args: { type: :user, separator: SEARCH_SEPARATOR } },
    confidence: { component: :search_confidence_range_field, args: {} },
    # handled in search_region_with_compass_fields
    longitude: { component: nil, args: {} },
    latitude: { component: nil, args: {} }
  }.freeze

  SEARCH_SELECT_TYPES = [
    :select_yes, :select_boolean, :select_misspellings,
    :select_rank_range, :select_confidence
  ].freeze

  def search_type_options
    [
      [:COMMENTS.l, :comments],
      [:GLOSSARY.l, :glossary_terms],
      [:HERBARIA.l, :herbaria],
      # Temporarily disabled for performance reasons. 2021-09-12 JDC
      # [:IMAGES.l, :images],
      [:LOCATIONS.l, :locations],
      [:NAMES.l, :names],
      [:OBSERVATIONS.l, :observations],
      [:PROJECTS.l, :projects],
      [:SPECIES_LISTS.l, :species_lists],
      [:HERBARIUM_RECORDS.l, :herbarium_records],
      [:USERS.l, :users],
      [:app_search_google.l, :google]
    ].sort
  end
end
# rubocop:enable Metrics/ModuleLength
