# frozen_string_literal: true

# helpers for search forms. These call field helpers in forms_helper.
# args should provide form, field, label at a minimum.
# rubocop:disable Metrics/ModuleLength
module SearchHelper
  # Filter panel for a search form. Sections are shown and collapsed.
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
  def search_field(form:, search:, field:, sections:)
    args = { form:, search:, field: }
    args[:label] ||= search_label(field)
    field_type = search_field_type_from_controller(field:)
    return unless field_type

    # Prepare args for the field helper.
    args = prepare_args_for_search_field(args, field_type)
    if field_type == :multiple_autocompleter
      args[:type] = if field == :project_lists
                      :project
                    else
                      field
                    end
    end
    # Re-add :sections for conditional fields.
    if [:names_fields_for_names, :names_fields_for_obs].include?(field_type)
      args = args.merge(sections:, search:)
    end

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

  # TODO: fix this, component should be field_type
  # Prepares HTML args for the field helper. This is where we can make
  # adjustments to the args hash before passing it to the field helper.
  # NOTE: Bootstrap 3 can't do full-width inline label/field.
  def prepare_args_for_search_field(args, field_type)
    if field_type == :text_field_with_label && args[:field] != :pattern
      args[:inline] = true
    end
    args[:help] = search_help_text(args, field_type)
    args[:hidden_name] = search_check_for_hidden_field_name(args)
    # args[:class] = "mb-3"
    args = search_prefill_or_select_values(args, field_type)

    args.except(:search)
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

  def search_prefill_or_select_values(args, field_type)
    if SEARCH_SELECT_TYPES.include?(field_type)
      args[:selected] = args[:search].send(args[:field]) || nil
    end
    args
  end

  ###############################################################
  #
  # FIELD HELPERS
  #
  def multiple_value_autocompleter(**args)
    args[:type] = search_autocompleter_type(args[:field])
    args[:separator] = SEARCH_SEPARATOR
    args[:textarea] = true
    args[:hidden_name] = :"#{args[:field]}_id"
    args[:hidden_value] = args.dig(:search, args[:field])
    autocompleter_field(**args)
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

  def names_fields_for_names(**args)
    rows = [[:include_synonyms, :exclude_original_names],
            [:include_subtaxa, :include_immediate_subtaxa]]
    search = args[:search]
    names_fields_for_search(rows:, search:)
  end

  def names_fields_for_obs(**args)
    rows = [[:include_synonyms, :include_subtaxa],
            [:include_all_name_proposals, :exclude_consensus]]
    search = args[:search]
    names_fields_for_search(rows:, search:)
  end

  def names_fields_for_search(rows:, search:)
    fields_for(:names) do |f_n|
      autocompleter_with_conditional_fields(
        form: f_n, field: :lookup, label: :NAMES.l, search:, sections: rows
      )
    end
  end

  # Complex mechanism: append collapsed fields to autocompleter that only appear
  # when autocompleter has a value. Only on names fields, for lookup modifiers.
  def autocompleter_with_conditional_fields(**args)
    return if args[:sections].blank?

    # rightward destructuring assignment, Ruby 3 feature
    args => { form:, field:, label:, search:, sections: }
    # If there are conditional rows that should appear if user input, add these
    append = autocompleter_conditional_rows(form:, search:, sections:)
    multiple_value_autocompleter(form:, field:, label:, append:)
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

  def select_yes(**)
    options = [
      ["", nil],
      ["yes", true]
    ]
    select_with_label(options:, inline: true, **)
  end

  def select_boolean(**)
    options = [
      ["", nil],
      ["yes", true],
      ["no", false]
    ]
    select_with_label(options:, inline: true, **)
  end

  def select_misspellings(**)
    options = [
      ["", nil],
      ["yes", :yes],
      ["no", :no],
      ["both", :either]
    ]
    select_with_label(options:, inline: true, **)
  end

  def select_rank_range(**args)
    [
      tag.div(class: "d-inline-block mr-4") do
        select_with_label(**search_rank_args(args))
      end,
      tag.div(class: "d-inline-block") do
        select_with_label(**search_rank_range_args(args))
      end
    ].safe_join
  end

  def search_rank_args(args)
    args.except(:search).merge(
      { options: Name.all_ranks, include_blank: true, inline: true }
    )
  end

  def search_rank_range_args(args)
    args.except(:search).merge(
      { field: "#{args[:field]}_range", label: :to.l, options: Name.all_ranks,
        include_blank: true, between: :optional, help: nil, inline: true }
    )
  end

  def select_confidence_range(**args)
    confidences = Vote.opinion_menu.map { |k, v| [k, Vote.percent(v)] }
    [
      tag.div(class: "d-inline-block mr-4") do
        select_with_label(**search_confidence_args(confidences, args))
      end,
      tag.div(class: "d-inline-block") do
        select_with_label(**search_confidence_range_args(confidences, args))
      end
    ].safe_join
  end

  def search_confidence_args(confidences, args)
    args.except(:search).merge(
      { options: confidences, include_blank: true, inline: true }
    )
  end

  def search_confidence_range_args(confidences, args)
    args.except(:search).merge(
      { field: "#{args[:field]}_range", label: :to.l, options: confidences,
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

  def search_column_classes
    "col-xs-12 col-sm-6 col-md-12 col-lg-6"
  end

  # Separator for autocompleter fields.
  SEARCH_SEPARATOR = ", "

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
    :yes, :boolean, :yes_no_both, :rank_range, :confidence
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
