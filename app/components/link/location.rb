# frozen_string_literal: true

# Anchor linking to a `Location`'s show page (when a Location is
# known) or to an observations-index filtered by `where=` (when only
# a free-text `where` string is available). The visible label is a
# pair of `<span>`s carrying the postal + scientific representation
# so per-user formatting can swap them via CSS. An optional `count:`
# appends " (N)"; an optional `click: true` appends " [Click for map]"
# / " [Search]" depending on the link target.
class Components::Link::Location < Components::Link::Object
  prop :where, _Nilable(String), default: nil
  prop :location,
       _Nilable(_Union(::Location, ::Mappable::MinimalLocation)),
       default: nil
  prop :count, _Nilable(Integer), default: nil
  prop :click, _Boolean, default: false

  def view_template
    if location_obj
      render_location_link
    else
      render_where_link
    end
  end

  private

  def render_location_link
    a(href: url_for(location_path(id: location_obj.id)),
      class: "show_location_link show_location_link_#{location_obj.id}") do
      render_label(location_obj.name)
      plain(" [#{:click_for_map.t}]") if @click
    end
  end

  def render_where_link
    a(href: url_for(observations_path(where: @where)),
      class: "index_observations_at_where_link") do
      render_label(@where)
      plain(" [#{:SEARCH.t}]") if @click
    end
  end

  def location_obj
    @location
  end

  def render_label(name)
    span do
      span(class: "location-postal") { plain(name) }
      span(class: "location-scientific") do
        plain(::Location.reverse_name(name))
      end
      plain(" (#{@count})") if @count
    end
  end
end
