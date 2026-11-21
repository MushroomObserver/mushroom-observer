# frozen_string_literal: true

# The "Seen at:" / "Collected from:" line, plus the vague-location
# notice. Both render as sibling `li`s -- callers wrap this in a
# `ul`, so the notice must be a sibling `li`, not a nested `p`.
class Components::ObservationFragment::Where < Components::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    li(class: "obs-where hanging-indent") do
      trusted_html(append_colon(where_label))
      render_location
    end
    render_vague_notice
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
    li(class: "vague-location-notice ml-3") { em { plain(title) } }
  end
end
