# frozen_string_literal: true

# helpers for pattern search forms. These call field helpers in forms_helper.
# args should provide form, field, label at a minimum.
module PatternSearchHelper
  def pattern_search_field(**args)
    field = args[:field]
    klass = args[:klass]
    args[:label] ||= :"search_#{field}".l
    helper = pattern_search_helper_for_field(field, klass)
    send(helper, **args)
  end

  # The subclasses say how they're going to parse their fields, so we can use
  # that to determine which helper to use.
  def pattern_search_helper_for_field(field, klass)
    type = klass.params[field][1]
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

  def pattern_search_yes_field(**args)
    check_box_with_label(value: "yes", **args)
  end

  def pattern_search_boolean_field(**args)
    options = [
      ["", null],
      ["yes", "yes"],
      ["no", "no"]
    ]
    select_with_label(options:, **args)
  end

  def pattern_search_yes_no_both_field(**args)
    options = [
      ["", null],
      ["yes", "yes"],
      ["no", "no"],
      ["both", "either"]
    ]
    select_with_label(options:, **args)
  end

  # The first field gets the label, the range field is optional
  def pattern_search_date_range_field(**args)
    tag.div(class: "row") do
      concat(tag.div(class: "col-xs-12 col-sm-6") do
        text_field_with_label(**args)
      end)
      concat(tag.div(class: "col-xs-12 col-sm-6") do
        text_field_with_label(**args.merge(
          label: :TO.l, optional: true, field: "#{args[:field]}_range"
        ))
      end)
    end
  end

  # The first field gets the label, the range field is optional
  def pattern_search_rank_range_field(**args)
    tag.div(class: "row") do
      concat(tag.div(class: "col-xs-12 col-sm-6") do
        select_with_label(options: Rank.all_ranks, **args)
      end)
      concat(tag.div(class: "col-xs-12 col-sm-6") do
        select_with_label(options: Rank.all_ranks, **args.merge(
          label: :TO.l, optional: true, field: "#{args[:field]}_range"
        ))
      end)
    end
  end
end
