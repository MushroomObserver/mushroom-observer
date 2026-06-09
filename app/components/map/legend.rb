# frozen_string_literal: true

# Border + consensus-color legend rendered under the map container.
# Mixed into `Components::Map`. Suppressed on location-only maps,
# where consensus bands are meaningless. Two rows: border (precision
# of the members) and color (consensus band). See #4159.
module Components::Map::Legend
  private

  def render_legend
    return unless legend_applies?

    div(class: "map-legend small text-muted mt-2") do
      render_legend_border_row
      render_legend_color_row
    end
  end

  # Legend is meaningful only when the map shows at least one
  # observation; on location-only maps the consensus color band is
  # never assigned, so the legend would be misleading.
  def legend_applies?
    mappable_objects.any? do |o|
      o.respond_to?(:observation?) && o.observation?
    end
  end

  def render_legend_border_row
    div(class: "map-legend-row") do
      render_legend_border_swatch(:crisp, :map_legend_border_crisp.t)
      render_legend_border_swatch(:dashed, :map_legend_border_dashed.t)
      render_legend_border_swatch(:none, :map_legend_border_none.t)
    end
  end

  def render_legend_border_swatch(style, label)
    span(class: "map-legend-item") do
      span(class: "map-legend-swatch map-legend-border-#{style}")
      plain(label)
    end
  end

  def render_legend_color_row
    div(class: "map-legend-row") do
      legend_color_entries.each do |color, label|
        render_legend_color_swatch(color, label)
      end
    end
  end

  # The location-only color row is intentionally omitted: the legend
  # only renders on maps that include at least one observation, and
  # obs-bearing MapSets always have a consensus band — so the blue
  # "location-only" color would never appear on a map whose legend is
  # visible.
  def legend_color_entries
    [
      [::Mappable::MapSet::CONFIRMED_COLOR, :map_legend_confirmed.t],
      [::Mappable::MapSet::TENTATIVE_COLOR, :map_legend_tentative.t],
      [::Mappable::MapSet::DISPUTED_COLOR, :map_legend_disputed.t],
      [::Mappable::MapSet::MIXED_COLOR, :map_legend_mixed.t]
    ]
  end

  def render_legend_color_swatch(color, label)
    span(class: "map-legend-item") do
      span(class: "map-legend-swatch map-legend-dot",
           style: "background:#{color};")
      plain(label)
    end
  end
end
