# frozen_string_literal: true

# The "Seen at:" / "Collected from:" line for an observation, plus the
# vague-location notice when applicable. Owns its own `li.obs-where`
# wrapper (see Components::ObservationFragment::Who for why).
class Components::ObservationFragment::Where < Components::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    li(class: "obs-where hanging-indent") do
      plain("#{where_label}: ")
      render_location
      render_vague_notice
    end
  end

  private

  def where_label
    if @obs.is_collection_location
      :show_observation_collection_location.t
    else
      :show_observation_seen_at.t
    end
  end

  def render_location
    if @user
      Link(type: :location,
           where: @obs.where, location: @obs.location, click: true)
    else
      plain(@obs.where)
    end
  end

  def render_vague_notice
    return unless @obs.location&.vague?

    title = :show_observation_vague_location.l.dup
    title << " #{:show_observation_improve_location.l}" if @user == @obs.user
    p(class: "vague-location-notice ml-3") { em { plain(title) } }
  end
end
