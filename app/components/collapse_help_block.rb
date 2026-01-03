# frozen_string_literal: true

# Collapse help block component - collapsible help text block
#
# @example
#   CollapseHelpBlock(id: "help_1") { "This is help text" }
#   CollapseHelpBlock(id: "help_2", direction: "up") { "More help" }
class Components::CollapseHelpBlock < Components::Base
  prop :target_id, String
  prop :direction, _Nilable(String), default: nil
  prop :mobile, _Boolean, default: false

  def view_template(&block)
    div_class = "well well-sm mb-3 help-block position-relative"
    div_class += " mt-3" if @direction == "up"

    div(class: "collapse", id: @target_id) do
      div(class: div_class) do
        yield if block
        if @direction
          arrow_class = "arrow-#{@direction}"
          arrow_class += " hidden-xs" unless @mobile
          div(class: arrow_class)
        end
      end
    end
  end
end
