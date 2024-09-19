# frozen_string_literal: true

# helpers for pattern search forms. These call field helpers in forms_helper.
# args should provide form, field, label at a minimum.
module FiltersHelper
  # Filter panel for a search form. Sections are shown and collapsed.
  # If sections[:collapsed] is present, part of the panel will be collapsed.
  def filter_panel(form:, filter:, heading:, sections:, model:)
    shown = filter_panel_shown(form:, sections:, model:)
    collapsed = filter_panel_collapsed(form:, sections:, model:)
    open = collapse = false
    if sections[:collapsed].present?
      collapse = heading
      open = filter.attributes.keys.intersect?(sections[:collapsed])
    end
    panel_block(heading: :"search_term_group_#{heading}".l,
                collapse:, open:, panel_bodies: [shown, collapsed])
  end

  def filter_panel_shown(form:, sections:, model:)
    return unless sections.is_a?(Hash) && sections[:shown].present?

    capture do
      sections[:shown].each do |field|
        concat(filter_row(form:, field:, model:, sections:))
      end
    end
  end

  # Content of collapsed section, composed of field rows.
  def filter_panel_collapsed(form:, sections:, model:)
    return unless sections.is_a?(Hash) && sections[:collapsed].present?

    capture do
      sections[:collapsed].each do |field|
        concat(filter_row(form:, field:, model:, sections:))
      end
    end
  end

  # Fields might be paired, so we need to check for that.
  def filter_row(form:, field:, model:, sections:)
    if field.is_a?(Array)
      tag.div(class: "row") do
        field.each do |subfield|
          concat(tag.div(class: filter_columns) do
            filter_field(form:, field: subfield, model:, sections:)
          end)
        end
      end
    else
      filter_field(form:, field:, model:, sections:)
    end
  end

  # Figure out what kind of field helper to call, based on definitions below.
  # Some field types need args, so there is both the component and args hash.
  def filter_field(form:, field:, model:, sections:)
    args = { form:, field:, model: }
    args[:label] ||= filter_label(field)
    field_type = filter_field_type_from_parser(field:, model:)
    component = FILTER_FIELD_HELPERS[field_type][:component]
    return unless component

    # Prepare args for the field helper. Requires but removes args[:model].
    args = prepare_args_for_filter_field(args, field_type, component)
    # Re-add sections and model for conditional fields.
    if component == :filter_autocompleter_with_conditional_fields
      args = args.merge(sections:, model:)
    end
    send(component, **args)
  end

  # The field's label.
  def filter_label(field)
    if field == :pattern
      :PATTERN.l
    else
      :"search_term_#{field}".l.humanize
    end
  end

  # The PatternSearch subclasses define how they're going to parse their
  # fields, so we can use that to assign a field helper.
  #   example: :parse_yes -> :filter_yes_field
  # If the field is :pattern, there's no assigned parser.
  def filter_field_type_from_parser(field:, model:)
    return :pattern if field == :pattern

    subclass = PatternSearch.const_get(model.capitalize)
    unless subclass.params[field]
      raise("No parser defined for #{field} in #{subclass}")
    end

    parser = subclass.params[field][1]
    parser.to_s.gsub(/^parse_/, "").to_sym
  end

  FILTER_SEPARATOR = ", "

  # Convenience for subclasses to access helper methods via subclass.params
  FILTER_FIELD_HELPERS = {
    pattern: { component: :text_field_with_label, args: {} },
    yes: { component: :filter_yes_field, args: {} },
    boolean: { component: :filter_boolean_field, args: {} },
    yes_no_both: { component: :filter_yes_no_both_field, args: {} },
    date_range: { component: :filter_date_range_field, args: {} },
    rank_range: { component: :filter_rank_range_field, args: {} },
    string: { component: :text_field_with_label, args: {} },
    list_of_strings: { component: :text_field_with_label, args: {} },
    list_of_herbaria: { component: :autocompleter_field,
                        args: { type: :herbarium,
                                separator: FILTER_SEPARATOR } },
    list_of_locations: { component: :autocompleter_field,
                         args: { type: :location,
                                 separator: FILTER_SEPARATOR } },
    list_of_names: { component: :filter_autocompleter_with_conditional_fields,
                     args: { type: :name, separator: FILTER_SEPARATOR } },
    list_of_projects: { component: :autocompleter_field,
                        args: { type: :project,
                                separator: FILTER_SEPARATOR } },
    list_of_species_lists: { component: :autocompleter_field,
                             args: { type: :species_list,
                                     separator: FILTER_SEPARATOR } },
    list_of_users: { component: :autocompleter_field,
                     args: { type: :user, separator: ", " } },
    confidence: { component: :filter_confidence_range_field, args: {} },
    longitude: { component: :filter_longitude_field, args: {} },
    latitude: { component: :filter_latitude_field, args: {} }
  }.freeze

  # Prepares HTML args for the field helper. This is where we can make
  # adjustments to the args hash before passing it to the field helper.
  # NOTE: Bootstrap 3 can't do full-width inline label/field.
  def prepare_args_for_filter_field(args, field_type, component)
    if component == :text_field_with_label && args[:field] != :pattern
      args[:inline] = true
    end
    args[:help] = filter_help_text(args, field_type)
    args[:hidden_name] = filter_check_for_hidden_name(args)

    FILTER_FIELD_HELPERS[field_type][:args].merge(args.except(:model))
  end

  def filter_help_text(args, field_type)
    component = FILTER_FIELD_HELPERS[field_type][:component]
    multiple_note = if component == :autocompleter_field
                      :pattern_search_terms_multiple.l
                    end
    [:"#{args[:model]}_term_#{args[:field]}".l, multiple_note].compact.join(" ")
  end

  # Overrides for the assumed name of the id field for autocompleter.
  def filter_check_for_hidden_name(args)
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
  # Complex mechanism: append collapsed fields to autocompleter that only appear
  # when autocompleter has a value. Only on the name field
  def filter_autocompleter_with_conditional_fields(**args)
    return if args[:sections].blank?

    append = filter_conditional_rows(sections: args[:sections],
                                     form: args[:form], model: args[:model])
    autocompleter_field(**args.except(:sections, :model).merge(append:))
  end

  # Rows that only uncollapse if an autocompleter field has a value.
  # Note the data-autocompleter-target attribute.
  def filter_conditional_rows(sections:, form:, model:)
    capture do
      tag.div(data: { autocompleter_target: "collapseFields" },
              class: "collapse") do
        sections[:conditional].each do |field|
          concat(filter_row(form:, field:, model:, sections:))
        end
      end
    end
  end

  def filter_yes_field(**args)
    options = [
      ["", nil],
      ["yes", "yes"]
    ]
    select_with_label(options:, inline: true, **args)
  end

  def filter_boolean_field(**args)
    options = [
      ["", nil],
      ["yes", "yes"],
      ["no", "no"]
    ]
    select_with_label(options:, inline: true, **args)
  end

  def filter_yes_no_both_field(**args)
    options = [
      ["", nil],
      ["yes", "yes"],
      ["no", "no"],
      ["both", "either"]
    ]
    select_with_label(options:, inline: true, **args)
  end

  # RANGE FIELDS The first field gets the label, name and ID of the actual
  # param; the end `_range` field is optional. The controller needs to check for
  # the second & join them with a hyphen if it exists (in both cases here).
  def filter_date_range_field(**args)
    tag.div(class: "row") do
      [
        tag.div(class: filter_columns) do
          text_field_with_label(**args.merge(
            { between: "(YYYY-MM-DD)" }
          ))
        end,
        tag.div(class: filter_columns) do
          text_field_with_label(**args.merge(
            { field: "#{args[:field]}_range", label: :to.l,
              help: nil, between: :optional }
          ))
        end
      ].safe_join
    end
  end

  def filter_rank_range_field(**args)
    [
      tag.div(class: "d-inline-block mr-4") do
        select_with_label(**args.merge(
          { inline: true, options: Name.all_ranks,
            include_blank: true, selected: nil }
        ))
      end,
      tag.div(class: "d-inline-block") do
        select_with_label(**args.merge(
          { label: :to.l, between: :optional, help: nil, inline: true,
            options: Name.all_ranks, include_blank: true, selected: nil,
            field: "#{args[:field]}_range" }
        ))
      end
    ].safe_join
  end

  def filter_confidence_range_field(**args)
    confidences = Vote.opinion_menu.map { |k, v| [k, Vote.percent(v)] }
    [
      tag.div(class: "d-inline-block mr-4") do
        select_with_label(**args.merge(
          { inline: true, options: confidences,
            include_blank: true, selected: nil }
        ))
      end,
      tag.div(class: "d-inline-block") do
        select_with_label(**args.merge(
          { label: :to.l, between: :optional, help: nil, inline: true,
            options: confidences, include_blank: true, selected: nil,
            field: "#{args[:field]}_range" }
        ))
      end
    ].safe_join
  end

  def filter_longitude_field(**args)
    text_field_with_label(**args.merge(between: "(-180.0 to 180.0)"))
  end

  def filter_latitude_field(**args)
    text_field_with_label(**args.merge(between: "(-90.0 to 90.0)"))
  end

  def filter_columns
    "col-xs-12 col-sm-6 col-md-12 col-lg-6"
  end
end
