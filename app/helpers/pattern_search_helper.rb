# frozen_string_literal: true

# helpers for pattern search forms. These call field helpers in forms_helper.
# args should provide form, field, label at a minimum.
module PatternSearchHelper
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

  def pattern_search_date_range_field(**args)
    concat(tag.div do
      tag.strong(args[:label])
    end)
    concat(tag.div(class: "row") do
      concat(tag.div(class: "col-12 col-sm-6") do
        text_field_with_label(
          **args.merge(label: :START.l, field: "#{args[:field]}_start")
        )
      end)
      concat(tag.div(class: "col-12 col-sm-6") do
        text_field_with_label(
          **args.merge(label: :END.l, field: "#{args[:field]}_end")
        )
      end)
    end)
  end

  def pattern_search_rank_range_field(**args)
    concat(tag.div do
      tag.strong(args[:label])
    end)
    concat(tag.div(class: "row") do
      concat(tag.div do
        select_with_label(
          options: Rank.all_ranks,
          **args.merge(label: :LOW.l, field: "#{args[:field]}_low")
        )
      end)
      concat(tag.div do
        select_with_label(
          options: Rank.all_ranks,
          **args.merge(label: :HIGH.l, field: "#{args[:field]}_high")
        )
      end)
    end)
  end
end
