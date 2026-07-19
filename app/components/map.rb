# frozen_string_literal: true

# Interactive map component for displaying locations and observations.
# Works with the Stimulus map controller to render Google Maps with
# markers and bounding boxes.

# The popup markup is a Bootstrap `.media` layout with a thumbnail for
# single-obs popups, and a header with "Show All" / "Map All" buttons
# for group popups.
#
# The rendering logic is split across three siblings under
# `app/components/map/`:
#
#   * `Components::Map::Clustering` (mixin) — Mappable::Clustered vs
#                                    CollapsibleCollection selection,
#                                    `decorate_mapset` writes the popup
#                                    caption via `Components::Map::Popup`.
#   * `Components::Map::Popup`      (Phlex view) — info-window HTML
#                                    (single-obs + group), coordinate
#                                    formatting. Rendered standalone by
#                                    `Components::Map` AND by
#                                    `Observations::MapsController#popup`
#                                    (the lazy-load JSON endpoint
#                                    clustered maps call on marker
#                                    click), so the two entry points
#                                    share the same popup HTML.
#   * `Components::Map::Legend`     (mixin) — border / consensus-color
#                                    legend rendered under the map
#                                    container.
#
# `Clustering` and `Legend` are `include`d into `Components::Map` at
# the bottom of the class body; `Popup` is rendered via
# `render(::Components::Map::Popup.new(set:, query:))` from inside
# `Clustering#decorate_mapset`. Their methods rely on instance
# variables (`@objects`, `@clustering`, `@query`, etc.) declared as
# props on the host class.
#
# @example Basic usage
#   Map(objects: [@location])
#
# @example Editable map for forms
#   Map(
#     objects: [@location],
#     editable: true,
#     map_type: "location",
#     controller: nil  # form has the controller
#   )
#
# @example Clustered observations map with cap banner
#   Map(
#     objects: @observations,
#     clustering: true,
#     capped: @observations_capped,
#     cluster_query_string: @cluster_query_string,
#     query: @query,
#     zoom: 2,
#     observations_loaded_count: @observations_loaded_count,
#     observations_total_count: @observations_total_count
#   )
#
class Components::Map < Components::Base
  # Upper bound on points for client-side dynamic clustering
  # (issue #4159). Above this size we fall back to the server-side
  # CollapsibleCollectionOfObjects, which buckets the input
  # geographically into a manageable number of marker sets.
  CLUSTER_MAX_OBJECTS = 10_000

  # Mappable: real AR records (Location, Observation) or their
  # `Mappable::Minimal*` analogs used by index/maps endpoints.
  prop :objects, _Array(_Union(::Location, ::Observation,
                               ::Mappable::MinimalLocation,
                               ::Mappable::MinimalObservation))
  prop :user, _Nilable(User), default: nil
  prop :map_div, String, default: "map_div"
  prop :controller, _Nilable(String), default: "map"
  prop :map_target, String, default: "mapDiv"
  prop :map_type, String, default: "info"
  prop :need_elevations_value, _Boolean, default: true
  prop :map_open, _Boolean, default: true
  prop :editable, _Boolean, default: false
  prop :controls, _Array(Symbol), default: -> { [:large_map, :map_type] }
  prop :location_format, _Nilable(String), default: nil
  prop :nothing_to_map, _Nilable(String), default: nil
  # Typed `Query` (not raw Hash). Used for URL minting in popup
  # links and by the `Mappable::ClusteredCollection` builder. Falls
  # back to `current_query` (controller's session-current query,
  # already validated by `query_from_q_param`) when omitted, so
  # view-layer callers don't have to thread it through.
  prop :query, _Nilable(::Query), default: nil
  # Dynamic-clustering toggle. When true AND the input fits under
  # CLUSTER_MAX_OBJECTS, emit a Mappable::ClusteredCollection (one
  # MapSet per object) and `data-clustering="true"`, which tells the
  # JS controller to wrap the markers in a MarkerClusterer.
  prop :clustering, _Boolean, default: false
  # Whether the server-side dataset was capped (so the client knows to
  # refetch on viewport changes). Drives the cap-banner visibility.
  prop :capped, _Boolean, default: false
  # Server-emitted "q[...]=…" base for cluster popup Show All / Map All
  # links. The JS controller can't rebuild this from window.location
  # alone (might be a saved-query id, or no q params at all).
  prop :cluster_query_string, _Nilable(String), default: nil
  # Initial zoom level forwarded to the JS via data-zoom.
  prop :zoom, _Nilable(Integer), default: nil
  # Counts shown in the cap-banner — meaningful only when clustering.
  prop :observations_loaded_count, _Nilable(Integer), default: nil
  prop :observations_total_count, _Nilable(Integer), default: nil

  def view_template
    # Cap banner is part of the clustering chrome — render even when
    # there are no observations to map, so the JS layer can flip it
    # visible after a refetch returns capped results.
    render_cap_banner

    if mappable_objects.any?
      render_map_container
      render_legend
    else
      render_nothing_to_map
    end
  end

  private

  # --------------------------------------------------------------
  # Object filtering / nothing-to-map fallback
  # --------------------------------------------------------------

  def mappable_objects
    @mappable_objects ||= @objects.reject do |obj|
      name = obj.respond_to?(:location) ? obj.location&.name : obj.name
      Location.is_unknown?(name)
    end
  end

  def nothing_to_map_text
    @nothing_to_map || :runtime_map_nothing_to_map.t
  end

  # `nothing_to_map_text` is typically a `:foo.tp` textile-processed
  # html_safe string (e.g. with `<em>` tags around model names),
  # so emit through `trusted_html` rather than `plain` which would
  # escape the entities.
  def render_nothing_to_map
    div(class: "w-100") { trusted_html(nothing_to_map_text) }
  end

  # --------------------------------------------------------------
  # Cap banner
  # --------------------------------------------------------------

  # The banner is only meaningful when the dataset was clustered (the
  # cap only kicks in on the clustering path). Skip the emit entirely
  # when either count is missing so the helper-era output shape is
  # preserved for non-cap callers.
  def render_cap_banner
    return unless @clustering
    return if @observations_loaded_count.nil? ||
              @observations_total_count.nil?

    div(id: "map_cap_banner", class: "alert alert-warning mt-2",
        style: (@capped ? nil : "display:none")) do
      trusted_html(
        :map_cap_banner.t(
          loaded: @observations_loaded_count.to_fs(:delimited),
          total: @observations_total_count.to_fs(:delimited)
        )
      )
    end
  end

  # --------------------------------------------------------------
  # Map container + data attributes
  # --------------------------------------------------------------

  def render_map_container
    div(class: "w-100 position-relative map-container") do
      div(id: @map_div,
          class: "position-absolute w-100 h-100",
          data: map_data_attributes)
    end
  end

  def map_data_attributes
    base_map_data_attributes.merge(optional_map_data_attributes)
  end

  def base_map_data_attributes
    {
      map_target: @map_target,
      map_type: @map_type,
      need_elevations_value: @need_elevations_value.to_s,
      map_open: @map_open.to_s,
      editable: @editable.to_s,
      controls: @controls.to_json,
      location_format: location_format_value,
      collection: collection_for_js.to_json,
      localization: localization_data.to_json
    }
  end

  def optional_map_data_attributes
    attrs = {}
    attrs[:controller] = @controller if @controller
    attrs[:zoom] = @zoom.to_s if @zoom
    attrs[:cluster_query_string] = @cluster_query_string if
      @cluster_query_string
    attrs[:clustering] = "true" if use_clustering?
    attrs[:capped] = "true" if @capped
    attrs
  end

  # Location format — caller wins, then the prop'd user's preference,
  # then the request's actual current_user (for callers that render
  # this component without passing user:), then the "postal" baseline.
  def location_format_value
    @location_format || @user&.location_format ||
      current_user&.location_format || "postal"
  end

  # Localization values shipped to the JS controller as a JSON blob on
  # `data-localization`. Includes the cap-banner template — looked up
  # via the raw `I18n.t` call (no textile processing) so the JS can
  # substitute `[loaded]` / `[total]` on every viewport refetch.
  def localization_data
    {
      nothing_to_map: nothing_to_map_text,
      observations: :observations.ti,
      locations: :locations.ti,
      show_all: :show_all.t,
      map_all: :map_all.t,
      map_cap_banner: I18n.t("#{MO.locale_namespace}.map_cap_banner")
    }
  end

  # --------------------------------------------------------------
  # Marker tooltip title
  # --------------------------------------------------------------

  def mapset_marker_title(set)
    strings = map_location_strings(set.objects)
    result = if strings.length > 1
               "#{strings.length} #{:locations.t}"
             else
               strings.first
             end
    num_obs = set.observations.length
    if num_obs > 1 && num_obs != strings.length
      num_str = "#{num_obs} #{:observations.t}"
      result += strings.length > 1 ? ", #{num_str}" : " (#{num_str})"
    end
    result
  end

  def map_location_strings(objects)
    objects.filter_map do |obj|
      if obj.location?
        obj.display_name(current_user)
      elsif obj.observation?
        observation_location_string(obj)
      end
    end.uniq
  end

  def observation_location_string(obs)
    if obs.location
      obs.location.display_name(current_user)
    elsif obs.lat
      "#{format_latitude(obs.lat)} #{format_longitude(obs.lng)}"
    end
  end

  # The URL `q=` Hash, derived from `effective_query.q_param`.
  def effective_query_param
    @effective_query_param ||= effective_query&.q_param
  end

  # Rendering modules live in their own files (`app/components/map/`).
  # Listed at the bottom of the class body so the constants they
  # reference (`CLUSTER_MAX_OBJECTS`) are defined when their bodies
  # first execute.
  include Clustering
  include Legend
  include EffectiveQuery
end
