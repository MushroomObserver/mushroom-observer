# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations::ExternalLinks
  class InfoFrameTest < ComponentTestCase
    def test_own_link_with_edit_permission_shows_edit_and_destroy
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      obs = link.observation
      # coprinus_comatus_obs is owned by rolf -- ExternalLink#can_edit?
      # checks the target's owner, not the link's own `user`.
      user = users(:rolf)

      html = render(frame_with(obs: obs, site_links: [link], user: user))

      assert_html(
        html, "button.destroy_external_link_link_#{link.id}"
      )
      assert_html(
        html, "a[data-modal='modal_#{link.type_tag}_#{link.id}']"
      )
    end

    def test_own_link_without_edit_permission_shows_no_mod_links
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      obs = link.observation
      # Not the target's owner (rolf), and not a member of the
      # external_site's project (empty_project -- mary is its only
      # member, per that fixture's own comment).
      user = users(:dick)
      assert_not(link.can_edit?(user),
                 "Need a user fixture without edit permission on this link")

      html = render(frame_with(obs: obs, site_links: [link], user: user))

      assert_no_html(html, "button.destroy_external_link_link_#{link.id}")
      assert_no_html(
        html, "a[data-modal='modal_#{link.type_tag}_#{link.id}']"
      )
    end

    def test_logged_out_viewer_shows_no_mod_links
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      obs = link.observation

      html = render(frame_with(obs: obs, site_links: [link], user: nil))

      assert_no_html(html, "button.destroy_external_link_link_#{link.id}")
    end

    # Sibling rows never show edit/destroy, even when the viewer has
    # edit permission on the sibling's own link -- it isn't this
    # observation's link to manage from this page.
    def test_sibling_link_never_shows_mod_links_even_with_permission
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      sibling = observations(:detailed_unknown_obs)
      user = users(:rolf)
      assert(link.can_edit?(user),
             "Need a user fixture with edit permission on this link")

      html = render(
        frame_with(obs: sibling, site_links: [], user: user,
                   sibling_site_links: [sibling_link(link, sibling)])
      )

      assert_html(html, "a[href='#{link.url}']")
      assert_no_html(html, "button.destroy_external_link_link_#{link.id}")
    end

    # A read-only reflection's own link can't be edited or destroyed on
    # MO at all (#4214) -- no InlineCRUDLinks, just a note pointing at
    # the source, even for a viewer who'd otherwise have permission.
    def test_reflection_shows_read_only_note_not_mod_links
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      obs = link.observation
      user = users(:rolf)
      assert(link.can_edit?(user),
             "Need a user fixture with edit permission on this link")
      obs.update_column(:reflected_at, Time.zone.now)

      html = render(frame_with(obs: obs, site_links: [link], user: user))

      assert_html(html, ".reflection-read-only-note",
                  text: :observation_reflection_read_only_note.l)
      assert_no_html(html, "button.destroy_external_link_link_#{link.id}")
      assert_no_html(
        html, "a[data-modal='modal_#{link.type_tag}_#{link.id}']"
      )
    end

    # ONE occurrence-wide "Sync now" button (#4215), shown to any
    # logged-in viewer -- sync applies no user input, so there is no
    # permission gate beyond login.
    def test_reflection_pane_shows_sync_button_to_any_logged_in_user
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      obs = link.observation
      user = users(:dick) # no edit permission on this observation
      obs.update_column(:reflected_at, Time.zone.now)
      path = routes.resync_observation_path(obs.id)

      html = render(frame_with(obs: obs, site_links: [link], user: user))

      assert_html(html, "form[action='#{path}'][method='post']")
      assert_html(html, "form button.reflection-sync-button",
                  text: :sync_now.ti)
      # Recent source-side edits can take a moment to propagate -- the
      # Turbo confirm dialog lets the user choose to wait instead.
      assert_html(
        html,
        "button.reflection-sync-button" \
        "[data-turbo-confirm='#{:observation_resync_confirm.l}']"
      )
      assert_equal(
        1, Nokogiri::HTML5.fragment(html).
             css("button.reflection-sync-button").size,
        "one occurrence-wide button, not one per row"
      )
    end

    def test_reflection_pane_hides_sync_button_when_logged_out
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      obs = link.observation
      obs.update_column(:reflected_at, Time.zone.now)

      html = render(frame_with(obs: obs, site_links: [link], user: nil))

      assert_no_html(html, ".reflection-sync-button")
    end

    # From a non-reflection member's page, a sibling reflection's row
    # carries the read-only note, and the pane still offers the
    # occurrence-wide Sync button, posting to THIS page's observation
    # (the job resolves the occurrence's reflections from any member).
    def test_sibling_reflection_gets_note_and_pane_gets_sync_button
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      sibling = link.observation
      sibling.update_column(:reflected_at, Time.zone.now)
      obs = observations(:detailed_unknown_obs)
      [sibling, obs].each { |o| o.update_column(:occurrence_id, nil) }
      occ = Occurrence.create!(user: obs.user, primary_observation: obs)
      obs.update!(occurrence: occ)
      sibling.update!(occurrence: occ)
      path = routes.resync_observation_path(obs.id)

      html = render(
        frame_with(obs: obs, site_links: [], user: users(:mary),
                   sibling_site_links: [sibling_link(link, sibling)])
      )

      assert_html(html, "li .reflection-read-only-note",
                  text: :observation_reflection_read_only_note.l)
      assert_html(html, "form[action='#{path}'][method='post']")
    end

    private

    def sibling_link(link, observation)
      InfoFrame::SiblingLink.new(link: link, observation: observation)
    end

    def frame_with(obs:, site_links:, user:, sibling_site_links: [])
      InfoFrame.new(
        site_links: site_links, sibling_site_links: sibling_site_links,
        frame_id: "external_link_frame_test", site_name: "iNaturalist",
        obs: obs, user: user
      )
    end
  end
end
