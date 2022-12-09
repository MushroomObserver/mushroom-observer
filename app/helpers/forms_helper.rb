# frozen_string_literal: true

# helpers for form tags
module FormsHelper
  # draw a help block with an arrow
  def help_block_with_arrow(direction = nil, **args, &block)
    content_tag(:div, class: "well well-sm help-block position-relative",
                      id: args[:id]) do
      concat(capture(&block).to_s)
      if direction
        klass = "arrow-#{direction}"
        klass += " hidden-xs" unless args[:mobile]
        concat(content_tag(:div, "", class: klass))
      end
    end
  end
end
