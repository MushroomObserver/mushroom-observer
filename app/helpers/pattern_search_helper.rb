# frozen_string_literal: true

# helpers for pattern search forms. These call field helpers in forms_helper.
# args should provide form, field, label at a minimum.
module PatternSearchHelper
  def pattern_search_field(**args)
    args[:label] ||= :"search_term_#{args[:field]}".l.humanize
    helper = pattern_search_helper_for_field(args[:field], args[:type])
    args = prepare_args_for_pattern_search_field(args, helper)
    send(helper, **args) if helper
  end

  # The subclasses say how they're going to parse their fields, so we can use
  # that to determine which helper to use.
  def pattern_search_helper_for_field(field, type)
    type = PatternSearch.const_get(type.capitalize).params[field][1]
    PATTERN_SEARCH_FIELD_HELPERS[type]
  end

  # Convenience for subclasses to access helper methods via PARAMS
  PATTERN_SEARCH_FIELD_HELPERS = {
    parse_boolean: :pattern_search_boolean_field,
    parse_yes_no_both: :pattern_search_yes_no_both_field,
    parse_date_range: :pattern_search_date_range_field,
    parse_rank_range: :pattern_search_rank_range_field,
    parse_string: :text_field_with_label
  }.freeze

  # Bootstrap 3 can't do full-width inline label/field.
  def prepare_args_for_pattern_search_field(args, helper)
    # args[:inline] = true if helper == :text_field_with_label

    args.except(:type)
  end

  def pattern_search_yes_field(**args)
    check_box_with_label(value: "yes", **args)
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
          text_field_with_label(**args)
        end,
        tag.div(class: "col-xs-12 col-sm-6") do
          text_field_with_label(**args.merge(
            { label: :TO.l, optional: true, field: "#{args[:field]}_range" }
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
            { label: :TO.l, optional: true, field: "#{args[:field]}_range" }
          ))
        end
      ].safe_join
    end
  end
end
