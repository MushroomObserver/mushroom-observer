# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Details::ExternalLinksTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  def test_renders_nothing_when_no_links_and_no_sites
    obs = observations(:detailed_unknown_obs)
    assert_empty(obs.external_links)

    html = render(panel_with(obs))

    assert_equal("", html.to_s.strip,
                 "Badge line should hide silently with nothing to show")
  end

  def test_renders_inaturalist_badge_only
    link = external_links(:imported_inat_obs_inat_link)
    obs = link.observation

    html = render(panel_with(obs))

    assert_html(html, "#observation_external_links")
    assert_html(
      html, "a.badge.badge-id[href='#{routes.external_link_path(link.id)}']",
      text: "iNat"
    )
    assert_no_html(html, "a.badge.badge-id", text: "MCP")
  end

  def test_renders_both_badges
    inat_link = external_links(:coprinus_comatus_obs_inaturalist_link)
    mcp_link = external_links(:coprinus_comatus_obs_mycoportal_link)
    obs = inat_link.observation

    html = render(panel_with(obs))

    assert_html(
      html,
      "a.badge.badge-id[href='#{routes.external_link_path(inat_link.id)}']",
      text: "iNat"
    )
    assert_html(
      html,
      "a.badge.badge-id[href='#{routes.external_link_path(mcp_link.id)}']",
      text: "MCP"
    )
  end

  # Regression test: SITE_BADGES' key must match ExternalSite's real
  # name casing ("MyCoPortal" -- see Tab::Name::Mycoportal,
  # Report::MycoPortal, etc. for the same spelling used everywhere
  # else in the app) or representative_link_for's `==` lookup silently
  # never finds a match and the MCP badge never renders, no matter how
  # many MyCoPortal links the observation has.
  def test_renders_mycoportal_badge
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    obs = link.observation

    html = render(panel_with(obs))

    assert_html(
      html, "a.badge.badge-id[href='#{routes.external_link_path(link.id)}']",
      text: "MCP"
    )
  end

  def test_badge_accordion_trigger_and_tooltip
    link = external_links(:imported_inat_obs_inat_link)
    obs = link.observation
    tooltip = :show_observation_shared_with_tooltip.l(site: "iNaturalist")

    html = render(panel_with(obs))

    assert_html(
      html,
      "a[data-toggle='collapse'][data-target='#pane_#{link.id}']" \
      "[data-parent='#external_links_accordion']" \
      "[data-turbo-frame='external_link_frame_#{link.id}']" \
      "[data-trigger='tooltip'][data-title='#{tooltip}']"
    )
  end

  def test_renders_accordion_pane_and_empty_turbo_frame_per_site
    inat_link = external_links(:coprinus_comatus_obs_inaturalist_link)
    mcp_link = external_links(:coprinus_comatus_obs_mycoportal_link)
    obs = inat_link.observation

    html = render(panel_with(obs))

    assert_html(html, "#external_links_accordion")
    assert_html(html, "#pane_#{inat_link.id}.collapse")
    assert_html(html, "#pane_#{mcp_link.id}.collapse")
    assert_html(
      html,
      "#pane_#{inat_link.id} turbo-frame#external_link_frame_#{inat_link.id}"
    )
    assert_html(
      html,
      "#pane_#{mcp_link.id} turbo-frame#external_link_frame_#{mcp_link.id}"
    )
  end

  def test_renders_new_link_when_sites_present
    obs = observations(:detailed_unknown_obs)
    sites = ::ExternalSite.all.to_a
    skip("Need at least one ExternalSite fixture") if sites.empty?

    html = render(panel_with(obs, sites: sites))

    assert_html(html, "a[data-modal='modal_external_link']")
  end

  def test_hides_new_link_when_no_sites
    link = external_links(:coprinus_comatus_obs_inaturalist_link)
    obs = link.observation

    html = render(panel_with(obs, sites: []))

    assert_no_html(html, "a[data-modal='modal_external_link']")
  end

  # Badges are informational and shown to a logged-out viewer, but the
  # add-link affordance still requires being logged in -- even when
  # `sites:` is (incorrectly, for this case) populated.
  def test_hides_new_link_for_logged_out_viewer_even_with_sites_present
    link = external_links(:imported_inat_obs_inat_link)
    obs = link.observation
    sites = ::ExternalSite.all.to_a
    skip("Need at least one ExternalSite fixture") if sites.empty?

    html = render(panel_with(obs, sites: sites, user: nil))

    assert_html(html, "#observation_external_links")
    assert_no_html(html, "a[data-modal='modal_external_link']")
  end

  def test_sibling_only_link_still_shows_badge
    obs = observations(:detailed_unknown_obs)
    assert_empty(obs.external_links)
    sibling = observations(:coprinus_comatus_obs)
    link = external_links(:coprinus_comatus_obs_inaturalist_link)

    html = render(panel_with(obs, siblings: [sibling]))

    assert_html(
      html, "a.badge.badge-id[href='#{routes.external_link_path(link.id)}']",
      text: "iNat"
    )
  end

  private

  def panel_with(obs, sites: nil, siblings: [], user: @user)
    Views::Controllers::Observations::Show::Details::ExternalLinks.new(
      obs: obs, user: user, sites: sites, siblings: siblings
    )
  end
end
