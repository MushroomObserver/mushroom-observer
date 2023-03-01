# frozen_string_literal: true

# helpers for form tags
module FormsHelper
  # draw a help block with an arrow
  def help_block_with_arrow(direction = nil, **args, &block)
    div_class = "well well-sm help-block position-relative"
    div_class += " mt-3" if direction == "up"

    content_tag(:div, class: div_class,
                      id: args[:id]) do
      concat(capture(&block).to_s)
      if direction
        arrow_class = "arrow-#{direction}"
        arrow_class += " hidden-xs" unless args[:mobile]
        concat(content_tag(:div, "", class: arrow_class))
      end
    end
  end

  def panel_with_outer_heading(**args, &block)
    html = []
    h_tag = (args[:h_tag].presence || :h4)
    html << content_tag(h_tag, args[:heading]) if args[:heading]
    html << panel_block(**args, &block)
    safe_join(html)
  end

  def panel_block(**args, &block)
    content_tag(
      :div,
      class: "panel panel-default #{args[:class]}",
      id: args[:id]
    ) do
      content_tag(:div, class: "panel-body #{args[:inner_class]}") do
        concat(capture(&block).to_s)
      end
    end
  end
end
