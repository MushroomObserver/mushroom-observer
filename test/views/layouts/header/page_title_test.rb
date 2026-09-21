# frozen_string_literal: true

require("test_helper")

# Contract tests for `Views::Layouts::Header::PageTitle` -- the
# title-bar strip below the top nav. Desktop (`md`+): two Bootstrap
# columns (title+edit-icons left, interest-icons+pager right). Mobile
# (below `md`): id badge + edit icons + interest icons + pager all on
# one row, with the object title on a separate row.
#
# Populates the `content_for` slots directly with marker strings
# rather than going through `add_show_title`/`add_id_badge`/etc. or
# the components they render (`Header::ObjectTitle`,
# `Components::IDBadge`, `Header::InterestIcons`, ...) -- those have
# their tests already. This file tests PageTitle's job: where it
# places each already-rendered fragment, and which
# responsive-visibility classes gate each copy.
module Views::Layouts
  class Header::PageTitleTest < ComponentTestCase
    TITLE = "<span class='title-marker'>Fungus</span>".html_safe
    ID_BADGE = "<button class='badge-id'>42</button>".html_safe
    EDIT_ICONS = "<a class='edit-icons-marker'>Edit</a>".html_safe
    INTEREST_ICONS = "<div class='interest-icons-marker'></div>".html_safe
    PREV_NEXT = "<nav class='pager-marker'></nav>".html_safe

    def test_desktop_and_mobile_each_get_one_copy_of_every_piece
      html = render_page_title("show")

      # Mobile top row: one visibility-gated copy of each of the four
      # icon/badge pieces.
      assert_html(html, ".col-12.d-md-none .badge-id")
      assert_html(html, ".col-12.d-md-none .edit-icons-marker")
      assert_html(html, ".col-12.d-md-none .interest-icons-marker")
      assert_html(html, ".col-12.d-md-none .pager-marker")

      # Desktop positions: same four pieces, gated the other way.
      assert_html(html, ".d-none.d-md-block .badge-id")
      assert_html(html,
                  ".show_title_nav .d-none.d-md-block .edit-icons-marker")
      assert_html(html, ".show_object_nav .interest-icons-marker")
      assert_html(html, ".show_object_nav .pager-marker")

      # The object title appears once in the output, not twice.
      assert_html(html, "#title .title-marker", count: 1)
    end

    def test_no_duplicate_ids_between_mobile_and_desktop_copies
      html = render_page_title("show")
      ids = Nokogiri::HTML5.fragment(html).css("[id]").pluck("id")

      assert_equal(ids.uniq.length, ids.length,
                   "Duplicate id(s): #{ids.tally.select { |_, n| n > 1 }.keys}")
    end

    def test_right_column_and_mobile_object_nav_absent_off_show_action
      html = render_page_title("edit")

      assert_no_html(html, ".interest-icons-marker")
      assert_no_html(html, ".pager-marker")
      # Badge and edit icons still appear at both positions.
      assert_html(html, ".col-12.d-md-none .badge-id")
      assert_html(html, ".d-none.d-md-block .badge-id")
      assert_html(html, ".col-12.d-md-none .edit-icons-marker")
    end

    def test_suppressed_on_index_action
      html = render_page_title("index")

      assert_no_html(html, ".title-marker")
      assert_no_html(html, ".badge-id")
      assert_no_html(html, ".edit-icons-marker")
      assert_no_html(html, ".interest-icons-marker")
      assert_no_html(html, ".pager-marker")
    end

    private

    # Runs against `page` (the one-off page instance rendered by
    # `render_page_title`) rather than `self` -- `controller`/
    # `content_for`/`column_classes` are page-instance methods, not
    # test-instance methods.
    def populate_slots(page, action)
      page.controller.define_singleton_method(:action_name) { action }
      page.column_classes
      page.content_for(:title) { TITLE }
      page.content_for(:id_badge) { ID_BADGE }
      page.content_for(:edit_icons) { EDIT_ICONS }
      page.content_for(:interest_icons) { INTEREST_ICONS }
      page.content_for(:prev_next_object) { PREV_NEXT }
    end

    def render_page_title(action)
      captured = nil
      test = self
      page_class = Class.new(Views::FullPageBase) do
        define_method(:view_template) do
          test.send(:populate_slots, self, action)
          captured = capture { render(Header::PageTitle.new) }
        end
        def around_template
          yield
        end
      end
      render(page_class.new)
      captured
    end
  end
end
