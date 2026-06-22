# frozen_string_literal: true

require("test_helper")

# Contract tests for `Views::Layouts::Header::EditDeleteIcons` —
# the edit/delete icon `<ul>` in the show-page title bar.
module Views::Layouts
  class Header::EditDeleteIconsTest < ComponentTestCase
    def setup
      super
      @obs = observations(:detailed_unknown_obs) # owned by mary
      @owner = users(:mary)
      @non_owner = users(:rolf)
    end

    def test_always_renders_ul
      html = render(Header::EditDeleteIcons.new(object: @obs, user: @non_owner))

      assert_html(html, "ul.object_edit")
    end

    def test_renders_empty_ul_when_cannot_edit
      html = render(Header::EditDeleteIcons.new(object: @obs, user: @non_owner))

      assert_no_html(html, "ul.object_edit li")
    end

    def test_renders_empty_ul_with_nil_user
      html = render(Header::EditDeleteIcons.new(object: @obs, user: nil))

      assert_html(html, "ul.object_edit")
      assert_no_html(html, "ul.object_edit li")
    end

    def test_renders_edit_and_delete_li_when_owner
      html = render(Header::EditDeleteIcons.new(object: @obs, user: @owner))

      assert_html(html, "ul.object_edit li", count: 2)
    end
  end
end
