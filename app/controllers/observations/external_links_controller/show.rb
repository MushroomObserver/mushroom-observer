# frozen_string_literal: true

# see external_links_controller.rb
module Observations::ExternalLinksController::Show
  # Informational Turbo Frame for a "Shared with" badge: every own +
  # sibling ExternalLink for the clicked link's site. The badge link
  # carries a `data-turbo-frame` attribute, so a click sends a real GET
  # with a `Turbo-Frame` request header; a direct (non-frame) visit --
  # e.g. someone following the URL straight -- falls back to
  # redirecting to the observation instead of rendering a bare fragment.
  def show
    set_ivars_for_show

    if request.headers["Turbo-Frame"]
      render_external_link_info_frame
    else
      redirect_to(permanent_observation_path(@observation))
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

  # Sorted by relationship_date, matching the pre-badge external-links
  # list panel's own row order.
  def site_links_for(obs, site)
    obs.external_links.select { |link| link.external_site_id == site.id }.
      sort_by(&:relationship_date)
  end

  def sibling_site_links_for(siblings, site)
    sib_links = siblings.flat_map do |sib|
      site_links_for(sib, site).map do |link|
        Views::Controllers::Observations::ExternalLinks::InfoFrame::
          SiblingLink.new(link: link, observation: sib)
      end
    end
    sib_links.sort_by { |sib_link| sib_link.link.relationship_date }
  end

  # The badge link re-navigates its Turbo Frame on every click (Turbo
  # has no built-in "fetch once" for repeat frame navigations). ETag
  # on the exact records the frame renders so a repeat click -- e.g.
  # re-opening a pane that was closed by clicking a sibling badge --
  # comes back as a cheap 304 instead of a full re-render, unless a
  # link was actually added/removed/edited since.
  def render_external_link_info_frame
    site_links = site_links_for(@observation, @site)
    sibling_links = sibling_site_links_for(@siblings, @site)
    # Etag on the real ExternalLink records (not the SiblingLink Data
    # wrapper -- it has no cache_key of its own) so the digest reacts
    # to actual updated_at changes.
    fresh_when(etag: site_links + sibling_links.map(&:link), public: false)
    return if performed?

    render(Views::Controllers::Observations::ExternalLinks::InfoFrame.new(
             site_links: site_links,
             sibling_site_links: sibling_links,
             frame_id: "external_link_frame_#{@external_link.id}",
             site_name: @site.name
           ), layout: false)
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
