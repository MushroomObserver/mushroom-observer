# frozen_string_literal: true

module ExternalLinksHelper
    # Get a list of external_sites which the user has permission to add
  # external_links to (and which no external_link to exists yet).
  def external_sites_user_can_add_links_to(obs)
    return [] unless (current_user = User.current)

    obs_site_ids = obs.external_links.map(&:external_site_id)
    if (current_user == obs.user) || in_admin_mode?
      ExternalSite.where.not(id: obs_site_ids)
    else
      current_user.external_sites.where.not(id: obs_site_ids)
    end
  end
end
