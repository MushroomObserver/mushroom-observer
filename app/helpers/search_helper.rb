# frozen_string_literal: true

# helpers for search forms. These call field helpers in forms_helper.
# args should provide form, field, label at a minimum.
# rubocop:disable Metrics/ModuleLength
module SearchHelper
  # Filter panel for a search form. Sections are shown and collapsed.
  # If sections[:collapsed] is present, part of the panel will be collapsed.
  def search_panel(form:, search:, heading:, sections:, model:)
    shown = search_panel_shown(form:, search:, sections:, model:)
    collapsed = search_panel_collapsed(form:, search:, sections:, model:)
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

  def search_panel_shown(form:, search:, sections:, model:)
    return unless sections.is_a?(Hash) && sections[:shown].present?

    capture do
      sections[:shown].each do |field|
        concat(search_row(form:, search:, field:, model:, sections:))
      end
    end
  end

  # Content of collapsed section, composed of field rows.
  def search_panel_collapsed(form:, search:, sections:, model:)
    return unless sections.is_a?(Hash) && sections[:collapsed].present?

    capture do
      sections[:collapsed].each do |field|
        concat(search_row(form:, search:, field:, model:, sections:))
      end
    end
  end

  # Fields might be paired, so we need to check for that.
  def search_row(form:, search:, field:, model:, sections:)
    if field.is_a?(Array)
      tag.div(class: "row") do
        field.each do |subfield|
          concat(tag.div(class: search_column_classes) do
            search_field(form:, search:, field: subfield, model:, sections:)
          end)
        end
      end
    else
      search_field(form:, search:, field:, model:, sections:)
    end
  end

  # Figure out what kind of field helper to call, based on definitions below.
  # Some field types need args, so there is both the component and args hash.
  def search_field(form:, search:, field:, model:, sections:)
    args = { form:, search:, field:, model: }
    args[:label] ||= search_label(field)
    field_type = search_field_type_from_controller(field:)
    component = SEARCH_FIELD_HELPERS[field_type][:component]
    return unless component

    # Prepare args for the field helper. Requires but removes args[:model].
    args = prepare_args_for_search_field(args, field_type, component)
    # Re-add sections and model for conditional fields.
    if component == :search_autocompleter_with_conditional_fields
      args = args.merge(sections:, model:, search:)
    end
    return search_region_with_compass_fields(**args) if field == :region

    send(component, **args)
  end

  # The field's label.
  def search_label(field)
    if field == :pattern
      :PATTERN.l
    else
      :"search_term_#{field}".l.humanize
    end
  end

  # The controllers define how they're going to parse their
  # fields, so we can use that to assign a field helper.
  def search_field_type_from_controller(field:)
    return :pattern if field == :pattern

    permitted = controller.permitted_search_params
    unless permitted[field]
      raise("No input defined for #{field} in #{controller.controller_name}")
    end

    parser = subclass.params[field][1]
    parser.to_s.gsub(/^parse_/, "").to_sym
  end

  # Prepares HTML args for the field helper. This is where we can make
  # adjustments to the args hash before passing it to the field helper.
  # NOTE: Bootstrap 3 can't do full-width inline label/field.
  def prepare_args_for_search_field(args, field_type, component)
    if component == :text_field_with_label && args[:field] != :pattern
      args[:inline] = true
    end
    args[:help] = search_help_text(args, field_type)
    args[:hidden_name] = search_check_for_hidden_field_name(args)
    args = search_prefill_or_select_values(args, field_type)

    SEARCH_FIELD_HELPERS[field_type][:args].merge(args.except(:model, :search))
  end

  def search_help_text(args, field_type)
    component = SEARCH_FIELD_HELPERS[field_type][:component]
    multiple_note = if component == :autocompleter_field
                      :pattern_search_terms_multiple.l
                    end
    [:"#{args[:model]}_term_#{args[:field]}".l, multiple_note].compact.join(" ")
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
  # Complex mechanism: append collapsed fields to autocompleter that only appear
  # when autocompleter has a value. Only on the name field.
  def search_autocompleter_with_conditional_fields(**args)
    return if args[:sections].blank?

    # rightward destructuring assignment ruby 3 feature
    args => { form:, model:, search:, sections: }
    append = search_conditional_rows(form:, model:, search:, sections:)
    autocompleter_field(
      **args.except(:sections, :model, :search), append:
    )
  end

  # Rows that only uncollapse if an autocompleter field has a value.
  # Note the data-autocompleter-target attribute.
  def search_conditional_rows(form:, model:, search:, sections:)
    capture do
      tag.div(data: { autocompleter_target: "collapseFields" },
              class: "collapse") do
        sections[:conditional].each do |field|
          concat(search_row(form:, field:, model:, search:, sections:))
        end
      end
    end
  end

  def search_yes_field(**)
    options = [
      ["", nil],
      ["yes", "yes"]
    ]
    select_with_label(options:, inline: true, **)
  end

  def search_boolean_field(**)
    options = [
      ["", nil],
      ["yes", "yes"],
      ["no", "no"]
    ]
    select_with_label(options:, inline: true, **)
  end

  def search_yes_no_both_field(**)
    options = [
      ["", nil],
      ["yes", "yes"],
      ["no", "no"],
      ["both", "either"]
    ]
    select_with_label(options:, inline: true, **)
  end

  def search_rank_range_field(**args)
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

  def search_confidence_range_field(**args)
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

  def search_region_with_compass_fields(**args)
    tag.div(data: { controller: "map", map_open: true }) do
      [
        form_location_input_find_on_map(form: args[:form], field: :region,
                                        value: args[:search].region,
                                        label: "#{:REGION.t}:"),
        search_compass_input_and_map(form: args[:form], search: args[:search])
      ].safe_join
    end
  end

  def search_compass_input_and_map(form:, search:)
    minimal_loc = search_minimal_location(search)
    capture do
      [
        form_compass_input_group(form:, obj: search),
        make_map(objects: [minimal_loc], editable: true, map_type: "location",
                 map_open: false, controller: nil)
      ].safe_join
    end
  end

  # To be mappable, we need to instantiate a minimal location from the search.
  def search_minimal_location(search)
    if search.north.present? && search.south.present? &&
       search.east.present? && search.west.present?
      Mappable::MinimalLocation.new(
        nil, nil, search.north, search.south, search.east, search.west
      )
    else
      Mappable::MinimalLocation.new(nil, nil, 0, 0, 0, 0)
    end
  end

  def search_longitude_field(**args)
    text_field_with_label(
      **args.except(:search), between: "(-180.0 to 180.0)"
    )
  end

  def search_latitude_field(**args)
    text_field_with_label(
      **args.except(:search), between: "(-90.0 to 90.0)"
    )
  end

  def search_column_classes
    "col-xs-12 col-sm-6 col-md-12 col-lg-6"
  end

  # Separator for autocompleter fields.
  SEARCH_SEPARATOR = ", "

  # Convenience for subclasses to access helper methods via subclass.params
  SEARCH_FIELD_HELPERS = {
    pattern: { component: :text_field_with_label, args: {} },
    yes: { component: :search_yes_field, args: {} },
    boolean: { component: :search_boolean_field, args: {} },
    yes_no_both: { component: :search_yes_no_both_field, args: {} },
    date_range: { component: :search_date_range_field, args: {} },
    rank_range: { component: :search_rank_range_field, args: {} },
    string: { component: :text_field_with_label, args: {} },
    list_of_strings: { component: :text_field_with_label, args: {} },
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
end
# rubocop:enable Metrics/ModuleLength
