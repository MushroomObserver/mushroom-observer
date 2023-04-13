# frozen_string_literal: true

# helpers for show Observation view
module ObservationsHelper
  ##### Portion of page title that includes consensus naming (site id) #########
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
  def show_obs_title(obs:, owner_naming: nil)
    capture do
      concat(:show_observation_header.t)
      concat(" #{obs.id || "?"}: ")
      concat(obs_title_consensus_id(name: obs.name, owner_naming: owner_naming))
    end
  end

  ##### Portion of page title that includes user's naming preference #########

  # Observer Preference: Hydnum repandum
  def owner_naming_line(obs)
    return unless User.current&.view_owner_id

    capture do
      concat(:show_observation_owner_id.t + ": ")
      concat(owner_favorite_or_explanation(obs).t)
    end
  end

  # gathers the user's @votes indexed by naming
  def gather_users_votes(obs, user = nil)
    return [] unless user

    obs.namings.each_with_object({}) do |naming, votes|
      votes[naming.id] =
        naming.votes.find { |vote| vote.user_id == user.id } ||
        Vote.new(value: 0)
    end
  end

  private

  # name portion of Observation title
  def obs_title_consensus_id(name:, owner_naming: nil)
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
        concat(" (#{:show_observation_site_id.t})") if owner_naming
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

  public

  def link_to_display_name_brief_authors(name)
    link_to(name.display_name_brief_authors.t,
            name_path(id: name.id))
  end

  def link_to_display_name_without_authors(name)
    link_to(name.display_name_without_authors.t,
            name_path(id: name.id))
  end
end
