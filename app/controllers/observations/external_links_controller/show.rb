# frozen_string_literal: true

# see external_links_controller.rb
module Observations::ExternalLinksController::Show
  # Informational modal for a "Shared with" badge: every own +
  # sibling ExternalLink for the clicked link's site.
  def show
    set_ivars_for_show

    respond_to do |format|
      format.turbo_stream { render_external_link_info_modal }
      format.html { redirect_to(permanent_observation_path(@observation)) }
    end
  end

  private

  def set_ivars_for_show
    @external_link = ExternalLink.show_includes.find(params[:id])
    @observation = Observation.strict_loading.
                   includes(:occurrence, external_links: :external_site).
                   find(@external_link.observation.id)
    @site = @external_link.external_site
    @siblings = load_siblings_with_external_links(@observation)
  end

  # Sibling observations (same Occurrence) with their external_links
  # eager-loaded, for the "Shared with" badges + info modal. Skips the
  # heavier associations `load_occurrence_data` pulls for the full
  # obs-show page render (collection_numbers, herbarium_records,
  # images, etc.) — only external_links are needed here.
  def load_siblings_with_external_links(obs)
    return [] unless obs.occurrence

    obs.occurrence.observations.where.not(id: obs.id).
      includes(external_links: :external_site)
  end

  def site_links_for(obs, site)
    obs.external_links.select { |link| link.external_site_id == site.id }
  end

  def sibling_site_links_for(siblings, site)
    siblings.flat_map do |sib|
      site_links_for(sib, site).map do |link|
        Views::Controllers::Observations::ExternalLinks::Modal::
          SiblingLink.new(link: link, observation: sib)
      end
    end
  end

  def render_external_link_info_modal
    render(Views::Controllers::Observations::ExternalLinks::Modal.new(
             site_links: site_links_for(@observation, @site),
             sibling_site_links: sibling_site_links_for(@siblings, @site),
             user: @user,
             modal_id: "modal_external_link_#{@external_link.id}",
             title: info_modal_title
           ))
  end

  # An `external_id` means the clicked link points at a specific
  # record on the site (an import, or a manually-entered id) -- safe
  # to say "Observation X on iNaturalist". A url-only manual link has
  # no confirmed corresponding record on the other site, so avoid
  # implying one; "Uploaded to iNaturalist" doesn't claim a match.
  #
  # Named distinctly from the main controller's own `modal_title`
  # (used by the create/edit form modal, gated on `action_name`) --
  # that method is defined directly on the class, so it would
  # otherwise shadow a same-named method from this included module
  # for every action, including `show`.
  def info_modal_title
    if @external_link.external_id.present?
      :show_observation_shared_on_site.t(
        id: @observation.id, site: @site.name
      )
    else
      :show_observation_uploaded_to_site.t(
        id: @observation.id, site: @site.name
      )
    end
  end

  def render_external_links_section_update
    # Refetch with just the external-links subtree the panel +
    # `sites_user_can_add_links_to_for_obs` access — much cheaper
    # than the full `show_includes` tree for a panel re-render.
    @observation = Observation.includes(
      :occurrence, external_links: { external_site: { project: :user_group } }
    ).find(@observation.id)
    siblings = load_siblings_with_external_links(@observation)
    @other_sites = ExternalSite.sites_user_can_add_links_to_for_obs(
      @user, @observation, admin: in_admin_mode?
    )
    klass = Views::Controllers::Observations::Show::Details::ExternalLinks
    render_obs_section_update(
      identifier: "external_links",
      panel: klass.new(obs: @observation, user: @user,
                       sites: @other_sites&.to_a, siblings: siblings)
    ) and return
  end
end
