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
    # linked companion observation for the changes, and Delete works as
    # for any observation since a reflection can be reimported (#5180).
    def test_reflection_keeps_edit_and_delete_icons
      @obs.update_column(:reflected_at, Time.zone.now)
      html = render_icons(user: @owner)
      edit_href = routes.edit_observation_path(@obs.id)
      destroy_action = routes.observation_path(@obs.id)

      assert_html(html, "div.object_edit .inline-icon-link", count: 3)
      assert_html(html, "div.object_edit a[href='#{edit_href}']")
      assert_html(html, "div.object_edit form[action='#{destroy_action}']")
    end

    def test_reflection_shows_read_only_status_icon
      @obs.update_column(:reflected_at, Time.zone.now)
      html = render_icons(user: @owner)

      assert_html(html, "div.object_edit .mo-icon-read-only")
      # Must render inside InlineLinkBlock's wrapper span -- that's
      # what gives it the same spacing/size as the edit/delete icons
      # beside it, instead of the sprite's larger default size.
      assert_html(html,
                  "div.object_edit span.inline-link-block.ml-3 " \
                  ".mo-icon-read-only")
    end

    def test_non_reflection_has_no_read_only_status_icon
      html = render_icons(user: @owner)

      assert_no_html(html, "div.object_edit .mo-icon-read-only")
    end

    private

    def render_icons(**)
      render(Header::EditDeleteIcons.new(object: @obs, **))
    end
  end
end
