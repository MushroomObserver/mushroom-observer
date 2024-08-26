# frozen_string_literal: true

# helpers for pattern search forms. These call field helpers in forms_helper.
# args should provide form, field, label at a minimum.
module PatternSearchHelper
  def pattern_search_boolean_field(**args)
    options = [
      ["", null],
      ["yes", "yes"],
      ["no", "no"]
    ]
    select_with_label(options:, **args)
  end

  def pattern_search_yes_field(**args)
    check_box_with_label(value: "yes", **args)
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
end
