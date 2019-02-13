# frozen_string_literal: true

# helpers for show Observation view
module ShowObservationHelper
  def show_obs_title(obs)
    @owner_id ? show_obs_title_site_id(obs) : show_obs_title_num_after_name(obs)
  end

  # Observation: Agaricus (5)
  def show_obs_title_num_after_name(obs)
    capture do
      concat(:show_observation_header.t)
      concat(" #{obs.id || "?"}: ")
      concat(obs.name.format_name.t)
    end
  end

  # Observation 5: Agaricus (Site ID)
  def show_obs_title_site_id(obs)
    capture do
      concat(:show_observation_header.t)
      concat(" #{obs.id || "?"}: ")
      concat(obs.name.format_name.t)
      concat(" (#{:show_observation_site_id.t})")
    end
  end

  # Observer Preference: Agaricus L.
  def owner_id_line(obs)
    return unless User.view_owner_id_on?

    capture do
      concat(:show_observation_owner_id.t + ": ")
      concat(owner_favorite_or_explanation(obs).t)
    end
  end

  def owner_favorite_or_explanation(obs)
    obs.owner_preference&.format_name || :show_observation_no_clear_preference
  end
end
