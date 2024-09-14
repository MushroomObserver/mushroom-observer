# frozen_string_literal: true

# helpers for pattern search forms. These call field helpers in forms_helper.
# args should provide form, field, label at a minimum.
module PatternSearchHelper
  def pattern_search_field(**args)
    args[:label] ||= pattern_search_helper_for_label(args[:field])
    field_type = pattern_search_field_type_from_parser(**args)
    component = PATTERN_SEARCH_FIELD_HELPERS[field_type][:component]
    args = prepare_args_for_pattern_search_field(args, field_type, component)
    send(component, **args) if component
  end

  def pattern_search_helper_for_label(field)
    if field == :pattern
      :PATTERN.l
    else
      :"search_term_#{field}".l.humanize
    end
  end

  # The PatternSearch subclasses define how they're going to parse their
  # fields, so we can use that to assign a field helper.
  #   example: :parse_yes -> :pattern_search_yes_field
  # If the field is :pattern, there's no assigned parser.
  def pattern_search_field_type_from_parser(**args)
    return :pattern if args[:field] == :pattern

    subclass = PatternSearch.const_get(args[:type].capitalize)
    unless subclass.params[args[:field]]
      raise("No parser defined for #{args[:field]} in #{subclass}")
    end

    parser = subclass.params[args[:field]][1]
    parser.to_s.gsub(/^parse_/, "").to_sym
  end

  PATTERN_SEARCH_SEPARATOR = ", "

  # Convenience for subclasses to access helper methods via subclass.params
  PATTERN_SEARCH_FIELD_HELPERS = {
    pattern: { component: :text_field_with_label, args: {} },
    yes: { component: :pattern_search_yes_field, args: {} },
    boolean: { component: :pattern_search_boolean_field, args: {} },
    yes_no_both: { component: :pattern_search_yes_no_both_field, args: {} },
    date_range: { component: :pattern_search_date_range_field, args: {} },
    rank_range: { component: :pattern_search_rank_range_field, args: {} },
    string: { component: :text_field_with_label, args: {} },
    list_of_strings: { component: :text_field_with_label, args: {} },
    list_of_herbaria: { component: :autocompleter_field,
                        args: { type: :herbarium,
                                separator: PATTERN_SEARCH_SEPARATOR } },
    list_of_locations: { component: :autocompleter_field,
                         args: { type: :location,
                                 separator: PATTERN_SEARCH_SEPARATOR } },
    list_of_names: { component: :autocompleter_field,
                     args: { type: :name,
                             separator: PATTERN_SEARCH_SEPARATOR } },
    list_of_projects: { component: :autocompleter_field,
                        args: { type: :project,
                                separator: PATTERN_SEARCH_SEPARATOR } },
    list_of_species_lists: { component: :autocompleter_field,
                             args: { type: :species_list,
                                     separator: PATTERN_SEARCH_SEPARATOR } },
    list_of_users: { component: :autocompleter_field,
                     args: { type: :user, separator: ", " } },
    confidence: { component: :pattern_search_confidence_field, args: {} },
    longitude: { component: :pattern_search_longitude_field, args: {} },
    latitude: { component: :pattern_search_latitude_field, args: {} }
  }.freeze

  # Prepares HTML args for the field helper. This is where we can make
  # adjustments to the args hash before passing it to the field helper.
  # NOTE: Bootstrap 3 can't do full-width inline label/field.
  def prepare_args_for_pattern_search_field(args, field_type, component)
    if component == :text_field_with_label && args[:field] != :pattern
      args[:inline] = true
    end
    args[:help] = pattern_search_help_text(args)

    PATTERN_SEARCH_FIELD_HELPERS[field_type][:args].merge(args.except(:type))
  end

  def pattern_search_help_text(args)
    :"#{args[:type]}_term_#{args[:field]}".l
  end

  # FIELD HELPERS
  #
  def pattern_search_yes_field(**args)
    options = [
      ["", nil],
      ["yes", "yes"]
    ]
    select_with_label(options:, inline: true, **args)
  end

  def pattern_search_boolean_field(**args)
    options = [
      ["", nil],
      ["yes", "yes"],
      ["no", "no"]
    ]
    select_with_label(options:, inline: true, **args)
  end

  def pattern_search_yes_no_both_field(**args)
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
  def pattern_search_date_range_field(**args)
    tag.div(class: "row") do
      [
        tag.div(class: "col-xs-12 col-sm-6") do
          # text_field_with_label(**args.merge(between: "(YYYY-MM-DD)"))
          date_select_with_label(**args.merge(
            { between: "(YYYY-MM-DD)", include_blank: true,
              selected: 0, order: [:year, :month, :day] }
          ))
        end,
        tag.div(class: "col-xs-12 col-sm-6") do
          date_select_with_label(**args.merge(
            { field: "#{args[:field]}_range", label: :to.l,
              between: :optional, help: nil, include_blank: true,
              selected: 0, order: [:year, :month, :day] }
          ))
        end
      ].safe_join
    end
  end

  def pattern_search_rank_range_field(**args)
    tag.div(class: "row") do
      [
        tag.div(class: "col-xs-12 col-sm-6") do
          select_with_label(options: Name.all_ranks, **args)
        end,
        tag.div(class: "col-xs-12 col-sm-6") do
          select_with_label(options: Name.all_ranks, **args.merge(
            { label: :to.l, between: :optional, help: nil,
              field: "#{args[:field]}_range" }
          ))
        end
      ].safe_join
    end
  end

  def pattern_search_confidence_field(**args)
    select_with_label(options: Vote.opinion_menu, **args)
  end

  def pattern_search_longitude_field(**args)
    text_field_with_label(**args.merge(between: "(-180.0 to 180.0)"))
  end

  def pattern_search_latitude_field(**args)
    text_field_with_label(**args.merge(between: "(-90.0 to 90.0)"))
  end
end
