# frozen_string_literal: true

# Legend shown under maps that include at least one observation.
# Suppressed on location-only maps, where consensus bands are
# meaningless. Three rows: shape (single vs multiple observation),
# border (precision of the members), and color (consensus band).
# See #4159.
module MapLegendHelper
  # Pass objects so we can suppress the legend on location-only maps.
  def map_legend(objects: nil)
    return "".html_safe unless legend_applies?(objects)

    tag.div(class: "map-legend small text-muted mt-2") do
      concat(map_legend_shape_row)
      concat(map_legend_border_row)
      concat(map_legend_color_row)
    end
  end

  private

  # Legend is meaningful only when the map shows at least one
  # observation. When `objects` is nil (callers that predate this
  # argument), fall back to the old unconditional behavior.
  def legend_applies?(objects)
    return true if objects.nil?

    objects.any? { |o| o.respond_to?(:observation?) && o.observation? }
  end

  def map_legend_shape_row
    tag.div(class: "map-legend-row") do
      concat(map_legend_shape_swatch(:circle, :map_legend_circle.t))
      concat(map_legend_shape_swatch(:box, :map_legend_box.t))
    end
  end

  def map_legend_border_row
    tag.div(class: "map-legend-row") do
      concat(map_legend_border_swatch(:crisp, :map_legend_border_crisp.t))
      concat(map_legend_border_swatch(:dashed, :map_legend_border_dashed.t))
      concat(map_legend_border_swatch(:none, :map_legend_border_none.t))
    end
  end

  def map_legend_border_swatch(style, label)
    tag.span(class: "map-legend-item") do
      concat(tag.span("", class: "map-legend-swatch " \
                                 "map-legend-border-#{style}"))
      concat(label)
    end
  end

  def map_legend_color_row
    tag.div(class: "map-legend-row") do
      map_legend_color_entries.each do |color, label|
        concat(map_legend_color_swatch(color, label))
      end
    end
  end

  # The location-only color row is intentionally omitted: the legend
  # only renders on maps that include at least one observation, and
  # obs-bearing MapSets always have a consensus band — so the blue
  # "location-only" color would never appear on a map whose legend is
  # visible.
  def map_legend_color_entries
    [
      [Mappable::MapSet::CONFIRMED_COLOR, :map_legend_confirmed.t],
      [Mappable::MapSet::TENTATIVE_COLOR, :map_legend_tentative.t],
      [Mappable::MapSet::DISPUTED_COLOR, :map_legend_disputed.t],
      [Mappable::MapSet::MIXED_COLOR, :map_legend_mixed.t]
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
