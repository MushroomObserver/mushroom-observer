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
