# frozen_string_literal: true

# The GPS coordinates line for an observation, when the viewer is
# logged in and the observation has a lat/lng. Owns its own
# `li.obs-where-gps` wrapper (see Components::ObservationFragment::Who
# for why). Renders nothing if there's no viewer or no coordinates --
# callers can render this unconditionally.
class Components::ObservationFragment::WhereGps < Components::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    return unless @obs.lat && @user

    li(class: "obs-where-gps indent") do
      # XXX Consider dropping this from indexes.
      render_gps_link if @obs.reveal_location?(@user)
      i { plain("(#{:show_observation_gps_hidden.t})") } if @obs.gps_hidden
    end
  end

  private

  def render_gps_link
    parts = [display_lat_lng(@obs.lat, @obs.lng).t, display_alt(@obs.alt).t]
    trusted_html(parts.compact_blank.join(" "))
    render_gps_map_link
  end

  def render_gps_map_link
    InlineLinkBlock(items: [gps_map_icon])
  end

  def gps_map_icon
    Components::Link::Icon.new(
      content: :click_for_map.l,
      path: map_observation_path(id: @obs.id),
      icon: :place,
      class: Components::InlineLinkBlock.item_class
    )
  end
end
