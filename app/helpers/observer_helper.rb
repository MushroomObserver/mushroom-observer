# frozen_string_literal: true

# helpers for show Observation view
module ObserverHelper
  ##### Portion of page title that includes consensus (site id) ################
  #
  # Depends on whether consensus is deprecated and user preferences include
  # showing Observer's Preference
  #
  # Consensus not deprecated, observer preference not shown:
  #   Observation nnn: Aaa bbb Author(s)
  # Consensus deprecated, observer preference not shown:
  #   Observation nnn: Ccc ddd Author(s) (Site ID) (Aaa bbb)
  # Observer preference shown, consensus not deprecated:
  #   Observation nnn: Aaa bbb Author(s) (Site ID)
  def show_obs_title(obs)
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
        concat(link_to_display_name_brief_authors(name))
        # Differentiate deprecated consensus from preferred name
        concat(" (#{:show_observation_site_id.t})")
        concat(" ") # concat space separately, else `.t` strips it
        concat("(")
        concat(link_to_display_name_without_authors(current_name))
        concat(")")
      end
    else
      capture do
        concat(link_to_display_name_brief_authors(name))
        # Differentiate this Name from Observer Preference
        concat(" (#{:show_observation_site_id.t})") if @owner_id
      end
    end
  end

  def owner_favorite_or_explanation(obs)
    if (name = obs.owner_preference)
      link_to_display_name_brief_authors(name)
    else
      :show_observation_no_clear_preference
    end
  end

  def link_to_display_name_brief_authors(name)
    link_to(name.display_name_brief_authors.t,
            controller: :name,
            action: :show_name, id: name.id)
  end

  def link_to_display_name_without_authors(name)
    link_to(name.display_name_without_authors.t,
            controller: :name,
            action: :show_name, id: name.id)
  end
end
