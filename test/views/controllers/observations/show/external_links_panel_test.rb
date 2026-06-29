# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::ExternalLinksPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_section_id
    html = render(panel_with(@obs))

    assert_html(html, "#observation_external_links")
  end

  def test_renders_own_external_links_with_mod_links_for_editor
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    obs = link.observation

    html = render(
      Views::Controllers::Observations::Show::ExternalLinksPanel.new(
        obs: obs, user: link.user, sites: nil, siblings: []
      )
    )

    assert_html(html, "li#external_link_#{link.id} a[href='#{link.url}']")
    assert_html(html,
                "form[action='#{routes.external_link_path(link.id)}']")
  end

  def test_renders_sibling_external_links_including_inaturalist
    # Both fixtures belong to `coprinus_comatus_obs` — use them as
    # "siblings" of `@obs` (which has no external_links of its own).
    sibling = observations(:coprinus_comatus_obs)

    html = render(
      Views::Controllers::Observations::Show::ExternalLinksPanel.new(
        obs: @obs, user: @user, sites: nil, siblings: [sibling]
      )
    )

    # Generic sibling link (mycoportal): relationship is the link text.
    mycoportal = external_links(:coprinus_comatus_obs_mycoportal_link)
    assert_html(html, "a[href='#{mycoportal.url}']",
                text: "Manual link to MycoPortal")
    # iNaturalist sibling link: "<relationship> (<id>)"
    inat = external_links(:coprinus_comatus_obs_inaturalist_link)
    assert_html(html, "a[href='#{inat.url}']",
                text: "Manual link to iNaturalist (234723)")
    # Per-sibling attribution: `<small class="text-muted">(MO N)</small>`
    sib_path = routes.permanent_observation_path(sibling.id)
    assert_html(html, "small.text-muted a[href='#{sib_path}']",
                text: "MO #{sibling.id}")
  end

  def test_empty_panel_renders_header_only
    # An obs with no external_links AND no siblings carrying any.
    obs = observations(:minimal_unknown_obs)
    skip("Need an obs with no external_links") if
      obs.external_links.any?

    html = render(
      Views::Controllers::Observations::Show::ExternalLinksPanel.new(
        obs: obs, user: @user, sites: nil, siblings: []
      )
    )

    # No `<ul>` body — `list_visible?` returns false.
    assert_no_html(html, "#observation_external_links ul")
    # No add-link button — `@sites` is empty/nil.
    assert_no_html(html, "a[data-modal='modal_external_link']")
  end

  def test_new_link_renders_when_sites_present
    sites = ::ExternalSite.all.to_a
    skip("Need at least one ExternalSite fixture") if sites.empty?

    html = render(
      Views::Controllers::Observations::Show::ExternalLinksPanel.new(
        obs: @obs, user: @user, sites: sites, siblings: []
      )
    )

    # `Components::Link::InlineAdd` emits
    # `[<a data-modal="modal_external_link">…</a>]`.
    assert_html(html, "a[data-modal='modal_external_link']")
  end

  def test_renders_relationship_description
    link = external_links(:imported_inat_obs_inat_link)
    obs = link.observation

    html = render(panel_with(obs, link.user))

    assert_html(html, "li#external_link_#{link.id} a",
                text: "Imported from iNaturalist (12345)")
  end

  def test_orders_own_links_by_relationship_date
    obs = observations(:detailed_unknown_obs)
    obs.external_links.destroy_all
    inat = external_sites(:inaturalist)
    older = ExternalLink.create!(
      user: @user, target: obs, external_site: inat, external_id: "111",
      relationship: :copy, external_created_on: Date.new(2018, 1, 1)
    )
    newer = ExternalLink.create!(
      user: @user, target: obs, external_site: inat, external_id: "222",
      relationship: :remote_manual, external_created_on: Date.new(2024, 1, 1)
    )

    html = render(panel_with(obs.reload))

    assert_operator(html.index("external_link_#{older.id}"), :<,
                    html.index("external_link_#{newer.id}"),
                    "own links should render oldest relationship_date first")
  end

  def test_renders_help_link
    html = render(panel_with(@obs))

    assert_html(html,
                "a[href*='/articles/58'] " \
                "span.glyphicon-question-sign")
  end

  private

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::ExternalLinksPanel.new(
      obs: obs, user: user, sites: [], siblings: []
    )
  end
end
