# frozen_string_literal: true

# Legend shown under maps that include at least one observation.
# Suppressed on location-only maps, where consensus bands are
# meaningless. Two rows: shape meanings (circle vs. box) and color
# meanings (consensus bands + mixed + location-only). See #4159.
module MapLegendHelper
  # Pass objects so we can suppress the legend on location-only maps.
  def map_legend(objects: nil)
    return "".html_safe unless legend_applies?(objects)

    tag.div(class: "map-legend small text-muted mt-2") do
      concat(map_legend_shape_row)
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
      [Mappable::MapSet::MIXED_COLOR, :map_legend_mixed.t],
      [Mappable::MapSet::LOCATION_ONLY_COLOR, :map_legend_location_only.t]
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
