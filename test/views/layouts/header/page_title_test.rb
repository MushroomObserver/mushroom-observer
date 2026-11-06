# frozen_string_literal: true

require("test_helper")

# Contract tests for `Views::Layouts::Header::PageTitle` -- the
# title-bar strip below the top nav. Desktop (`sm`+): two Bootstrap
# columns (title+edit-icons left, interest-icons+pager right). Mobile
# (below `sm`): id badge + edit icons + interest icons + pager all on
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
    CTA = "<button class='cta-marker'>Create</button>".html_safe
    EDIT_ICONS = "<a class='edit-icons-marker'>Edit</a>".html_safe
    INTEREST_ICONS = "<div class='interest-icons-marker'></div>".html_safe
    PREV_NEXT = "<nav class='pager-marker'></nav>".html_safe

    def test_desktop_and_mobile_each_get_one_copy_of_every_piece
      html = render_page_title("show")

      # Mobile top row: one visibility-gated copy of each piece.
      assert_html(html, ".col-12.d-sm-none .badge-id")
      assert_html(html, ".col-12.d-sm-none .cta-marker")
      assert_html(html, ".col-12.d-sm-none .edit-icons-marker")
      assert_html(html, ".col-12.d-sm-none .interest-icons-marker")
      assert_html(html, ".col-12.d-sm-none .pager-marker")

      # Desktop positions: same pieces, gated the other way.
      assert_html(html, ".id_badge_wrap.d-none.d-sm-block .badge-id")
      assert_html(html,
                  ".show_title_nav .title_bar_cta_wrap.d-none.d-sm-block " \
                  ".cta-marker")
      assert_html(html,
                  ".show_title_nav .title_bar_actions_wrap.d-none.d-sm-flex " \
                  ".edit-icons-marker")
      assert_html(html, ".show_object_nav .interest-icons-marker")
      assert_html(html, ".show_object_nav .pager-marker")

      # The object title appears once in the output, not twice.
      assert_html(html, "#title .title-marker", count: 1)
    end

    # CTA (a form's submit button) sits right after the title; the
    # actions slot (edit/destroy icons) sits in a separate wrapper
    # after that -- distinct slots for distinct positions, not one
    # slot guessing from content.
    def test_cta_sits_after_title_actions_sit_flush_right
      html = render_page_title("show")

      assert_html(html, "#title + .title_bar_cta_wrap .cta-marker")
      assert_no_html(html, ".title_bar_cta_wrap .edit-icons-marker")
      assert_html(html, ".title_bar_actions_wrap .edit-icons-marker")
      assert_no_html(html, ".title_bar_actions_wrap .cta-marker")
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
      # Badge, CTA, and edit icons still appear at both positions.
      assert_html(html, ".col-12.d-sm-none .badge-id")
      assert_html(html, ".id_badge_wrap.d-none.d-sm-block .badge-id")
      assert_html(html, ".col-12.d-sm-none .cta-marker")
      assert_html(html, ".col-12.d-sm-none .edit-icons-marker")
    end

    # `new`/`create` pages have no object yet, so `add_id_badge`/
    # `add_edit_icons` don't run -- no empty wrapper div should be
    # left behind for any of the three slots.
    def test_id_badge_and_edit_icons_wrappers_absent_when_unset
      html = render_page_title_title_only("new")

      assert_no_html(html, ".id_badge_wrap")
      assert_no_html(html, ".title_bar_cta_wrap")
      assert_no_html(html, ".title_bar_actions_wrap")
      assert_html(html, "#title .title-marker")
    end

    # Only Locations/Names/Observations/SpeciesLists show pages call
    # add_interest_icons/add_pager_for -- every other model's show
    # page must not get an empty flex row here (#5348 follow-up).
    def test_right_column_absent_on_show_action_without_icons_or_pager
      html = render_page_title("show", with_right_column_content: false)

      assert_no_html(html, ".title_bar_right_col")
      assert_no_html(html, ".show_object_nav")
      # Mobile row still omits the (unset) icons/pager, but keeps
      # the pieces that are set.
      assert_html(html, ".col-12.d-sm-none .badge-id")
      assert_no_html(html, ".col-12.d-sm-none .interest-icons-marker")
      assert_no_html(html, ".col-12.d-sm-none .pager-marker")
    end

    # A column-less show page (e.g. SpeciesLists::Show) has no right
    # column for interest-icons/pager to render into -- they render
    # inline instead, after the edit icons, both inside the actions
    # div (see render_inline_object_nav / render_title_bar_actions).
    def test_inline_object_nav_when_page_has_no_columns
      html = render_page_title("show", with_columns: false)

      assert_no_html(html, ".title_bar_right_col")
      assert_no_html(html, ".show_object_nav")
      assert_html(html, ".title_bar_actions_wrap .interest-icons-marker")
      assert_html(html, ".title_bar_actions_wrap .pager-marker")
      assert_html(html, ".title_bar_actions_wrap .edit-icons-marker")
      # Mobile row is unaffected by has_columns -- same inline
      # treatment it always uses.
      assert_html(html, ".col-12.d-sm-none .interest-icons-marker")
      assert_html(html, ".col-12.d-sm-none .pager-marker")
    end

    def test_suppressed_on_index_action
      html = render_page_title("index")

      assert_no_html(html, ".title-marker")
      assert_no_html(html, ".badge-id")
      assert_no_html(html, ".cta-marker")
      assert_no_html(html, ".edit-icons-marker")
      assert_no_html(html, ".interest-icons-marker")
      assert_no_html(html, ".pager-marker")
    end

    # projects#show renders a title inside ProjectBanner.
    def test_suppressed_on_projects_show_with_banner
      html = render_page_title("show", controller_path: "projects",
                                       with_project_banner: true)

      assert_no_html(html, ".title-marker")
    end

    # A project sub-page (e.g. aliases#new) gets a heading alongside
    # the banner's project title.
    def test_not_suppressed_on_project_subpage_with_banner
      html = render_page_title("new", controller_path: "projects/aliases",
                                      with_project_banner: true,
                                      with_columns: false)

      assert_html(html, ".title-marker")
    end

    private

    # Runs against `page` (the one-off page instance rendered by
    # `render_page_title`) rather than `self` -- `controller`/
    # `content_for`/`column_classes` are page-instance methods, not
    # test-instance methods.
    def populate_slots(page, action, with_right_column_content: true,
                       with_columns: true, **project_opts)
      page.controller.define_singleton_method(:action_name) { action }
      populate_project_slots(page, **project_opts)
      # A non-:twelve split -- the interest-icons/pager right column
      # only renders for a page that has one (see
      # test_inline_object_nav_when_page_has_no_columns below for the
      # column-less case, where `column_classes` is left at its
      # :twelve default).
      page.column_classes(:eight_four) if with_columns
      page.content_for(:title) { TITLE }
      page.content_for(:id_badge) { ID_BADGE }
      page.content_for(:title_bar_cta) { CTA }
      page.content_for(:title_bar_actions) { EDIT_ICONS }
      return unless with_right_column_content

      page.content_for(:interest_icons) { INTEREST_ICONS }
      page.content_for(:prev_next_object) { PREV_NEXT }
    end

    # Stubs the project-page suppression inputs for `on_project_page?`
    # (`controller_path`, `content_for(:project_banner)`).
    def populate_project_slots(page, controller_path: nil,
                               with_project_banner: false)
      if controller_path
        page.controller.define_singleton_method(:controller_path) do
          controller_path
        end
      end
      return unless with_project_banner

      page.content_for(:project_banner) { "<div>banner</div>".html_safe }
    end

    def render_page_title(action, **)
      captured = nil
      test = self
      StubPage.class_eval do
        define_method(:view_template) do
          test.send(:populate_slots, self, action, **)
          captured = capture { render(Header::PageTitle.new) }
        end
      end
      render(StubPage.new)
      captured
    end

    # Only `title`, matching a `new`/`create` page -- no object yet
    # for `add_id_badge`/`add_edit_icons` to run against.
    def render_page_title_title_only(action)
      captured = nil
      StubTitleOnlyPage.class_eval do
        define_method(:view_template) do
          controller.define_singleton_method(:action_name) { action }
          column_classes
          content_for(:title) { TITLE }
          captured = capture { render(Header::PageTitle.new) }
        end
      end
      render(StubTitleOnlyPage.new)
      captured
    end

    # Named (not `Class.new(...) do ... end`) so LocalizationFilesTest's
    # duplicate-method scanner sees each `around_template` in a
    # separate scope -- see phlex_reference.md.
    class StubPage < Views::FullPageBase
      def around_template
        yield
      end
    end

    class StubTitleOnlyPage < Views::FullPageBase
      def around_template
        yield
      end
    end
  end
end
