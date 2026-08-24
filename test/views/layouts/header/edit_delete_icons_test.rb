# frozen_string_literal: true

require("test_helper")

# Contract tests for `Views::Layouts::Header::EditDeleteIcons` —
# the edit/delete icon pair in the show-page title bar.
module Views::Layouts
  class Header::EditDeleteIconsTest < ComponentTestCase
    def setup
      super
      @obs = observations(:detailed_unknown_obs) # owned by mary
      @owner = users(:mary)
      @non_owner = users(:rolf)
    end

    def test_always_renders_container
      html = render_icons(user: @non_owner)

      assert_html(html, "div.object_edit")
    end

    def test_renders_empty_when_cannot_edit
      html = render_icons(user: @non_owner)

      assert_no_html(html, "div.object_edit .inline-icon-link")
    end

    def test_renders_empty_with_nil_user
      html = render_icons(user: nil)

      assert_html(html, "div.object_edit")
      assert_no_html(html, "div.object_edit .inline-icon-link")
    end

    def test_renders_edit_and_delete_items_when_owner
      html = render_icons(user: @owner)

      assert_html(html, "div.object_edit .inline-icon-link", count: 2)
      edit_href = routes.edit_observation_path(@obs.id)
      destroy_action = routes.observation_path(@obs.id)
      assert_html(html, "div.object_edit a[href='#{edit_href}']")
      assert_html(html, "div.object_edit form[action='#{destroy_action}']")
    end

    # A read-only reflection (#4214) keeps both icons: Edit opens a
    # linked companion observation for the changes.
    def test_reflection_keeps_edit_and_delete_icons
      @obs.update_column(:reflected_at, Time.zone.now)
      html = render_icons(user: @owner)
      edit_href = routes.edit_observation_path(@obs.id)
      destroy_action = routes.observation_path(@obs.id)

      assert_html(html, "div.object_edit .inline-icon-link", count: 2)
      assert_html(html, "div.object_edit a[href='#{edit_href}']")
      assert_html(html, "div.object_edit form[action='#{destroy_action}']")
    end

    private

    def render_icons(**)
      render(Header::EditDeleteIcons.new(object: @obs, **))
    end
  end
end
