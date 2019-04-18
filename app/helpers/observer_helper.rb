# frozen_string_literal: true

# helpers for show Observation view
module ObserverHelper
  ##### Portion of page title that includes consensus (site id) ################

  def show_obs_title(obs)
    @owner_id ? obs_title_with_name_and_site_id(obs) : obs_title_with_name(obs)
  end

  # Observation nnn: Hydnum washingtonianum (Site ID)
  #   or, if name is deprecated, include preferred name in parentheses
  # Observation nnn: Hydnum neorepandum (Hydnum washingtonianum) (Site ID)
  def obs_title_with_name_and_site_id(obs)
    capture do
      concat(obs_title_with_name(obs))
      # "(Site ID)" differentiates this Name from Observer Preference
      concat(" (#{:show_observation_site_id.t})")
    end
  end

  # Same as above, sans (Site ID)
  # Used when user prefers not to display Observer Preference
  def obs_title_with_name(obs)
    capture do
      concat(:show_observation_header.t)
      concat(" #{obs.id || "?"}: ")
      concat(obs_title_consensus_id(obs.name))
    end
  end

  ##### Portion of page title that includes Observer Preference ################

  # Observer Preference: Hydnum repandum
  def owner_id_line(obs)
    return unless User.view_owner_id_on?

    capture do
      concat(:show_observation_owner_id.t + ": ")
      concat(owner_favorite_or_explanation(obs).t)
    end
  end

  private ######################################################################

  # name portion of Observation title
  def obs_title_consensus_id(name)
    if name.deprecated &&
       (current_name = name.best_preferred_synonym).present?
      capture do
        concat(name.short_authors_display_name.t)
        concat(" ") # concat leading space separately since `.t` would strip it
        concat("(#{current_name.display_name_without_authors})".t)
      end
    else
      name.short_authors_display_name.t
    end
  end

  def owner_favorite_or_explanation(obs)
    obs.owner_preference&.format_name || :show_observation_no_clear_preference
  end
end
