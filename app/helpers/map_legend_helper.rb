# frozen_string_literal: true

# Legend shown under every map rendered via MapHelper#make_map.
# Two rows: shape meanings (circle vs. box) and color meanings
# (consensus bands + group). See #4131.
module MapLegendHelper
  def map_legend
    tag.div(class: "map-legend small text-muted mt-2") do
      concat(map_legend_shape_row)
      concat(map_legend_color_row)
    end
  end

  private

  def map_legend_shape_row
    tag.div(class: "map-legend-row") do
      concat(map_legend_shape_swatch(:circle, :map_legend_circle.t))
      concat(map_legend_shape_swatch(:box, :map_legend_box.t))
    end
  end

  def map_legend_color_row
    tag.div(class: "map-legend-row") do
      map_legend_color_entries.each do |color, label|
        concat(map_legend_color_swatch(color, label))
      end
    end
  end

  def map_legend_color_entries
    [
      [Mappable::MapSet::CONFIRMED_COLOR, :map_legend_confirmed.t],
      [Mappable::MapSet::TENTATIVE_COLOR, :map_legend_tentative.t],
      [Mappable::MapSet::DISPUTED_COLOR, :map_legend_disputed.t],
      [Mappable::MapSet::GROUP_COLOR, :map_legend_group.t]
    ]
  end

  def map_legend_shape_swatch(shape, label)
    tag.span(class: "map-legend-item") do
      concat(tag.span("", class: "map-legend-swatch map-legend-#{shape}"))
      concat(label)
    end
  end

  def map_legend_color_swatch(color, label)
    tag.span(class: "map-legend-item") do
      concat(tag.span("", class: "map-legend-swatch map-legend-dot",
                          style: "background:#{color};"))
      concat(label)
    end
  end
end
