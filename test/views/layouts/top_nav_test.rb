# frozen_string_literal: true

require("test_helper")

# Tests for `Views::Layouts::TopNav` — the page-chrome navbar that
# inlined the former `Header::TogglesHelper` / `Header::RubricHelper`
# helpers. The deleted helper test file had no Phlex equivalent;
# these tests pin the behaviour those helpers used to cover.
class Views::Layouts::TopNavTest < ComponentTestCase
  # Subclass with `render_search_row` neutralized — the search-bar /
  # identify-filter partials resolve through Rails view-paths that
  # aren't on the test controller's `append_view_path`. We render the
  # subclass instead of monkey-patching the real class, so the change
  # doesn't leak across the test process (an earlier version that
  # `define_method`'d on `Views::Layouts::TopNav` directly silently
  # broke the search-bar's `<select>` in every test that ran after
  # this file).
  class TopNavWithoutSearchRow < Views::Layouts::TopNav
    private

    def render_search_row
      nil
    end
  end

  def setup
    super
    @user = users(:rolf)
    stub_controller_name!("observations")
    stub_controller_path!("observations")
    define_action_methods!([:new, :index, :show])
  end

  # ---- nav_create (+ Add button) -------------------------------------

  def test_nav_create_button_renders_for_creatable_controller
    html = render(top_nav(user: @user))

    # `.btn-success` IS contract here (this rule's exception:
    # the create button's "green" styling is part of its identity).
    assert_html(html, "a.btn-success[href='#{routes.new_observation_path}']")
    # aria-label and title are the localized "New Observation" string
    full_label = "#{:NEW.l} #{:OBSERVATION.l}"
    assert_html(html, "a.btn-success[aria-label='#{full_label}']")
    assert_html(html, "a.btn-success[title='#{full_label}']")
    assert_html(html, "a.btn-success[data-toggle='tooltip']")
    # Responsive content: the word "Add" appears in a span hidden at
    # xs width and shown at sm and up.
    assert_html(html, "a.btn-success span.d-none.d-sm-inline",
                text: :ADD.l)
  end

  def test_nav_create_hidden_when_user_absent
    html = render(top_nav(user: nil))

    assert_no_html(html, "a.btn-success")
  end

  def test_nav_create_hidden_for_non_creatable_controller
    # `articles` IS in NAV_CREATABLES; pick one that isn't:
    # `descriptions`.
    stub_controller_name!("descriptions")
    stub_controller_path!("descriptions")

    html = render(top_nav(user: @user))

    assert_no_html(html, "a.btn-success")
  end

  def test_nav_create_hidden_when_controller_has_no_new_action
    define_action_methods!([:index, :show])

    html = render(top_nav(user: @user))

    assert_no_html(html, "a.btn-success")
  end

  # ---- nav_rubric ----------------------------------------------------

  def test_rubric_renders_as_index_link_when_on_show_page
    controller.params[:action] = "show"
    define_singleton_action_name!("show")

    html = render(top_nav(user: @user))

    selector = "#rubric a[href='#{routes.observations_path}']"
    assert_html(html, selector)
    assert_html(html, selector, text: :OBSERVATIONS.t)
  end

  def test_rubric_renders_as_plain_text_on_index_page
    define_singleton_action_name!("index")

    html = render(top_nav(user: @user))

    # On the index page with no filtering query, the rubric is plain
    # text — no link.
    assert_html(html, "h4#rubric")
    assert_no_html(html, "#rubric a")
  end

  # ---- nav_scan_qr_code ---------------------------------------------

  def test_qr_code_link_visible_for_observations_controller
    html = render(top_nav(user: @user))

    assert_html(html, "a[href='#{routes.field_slips_qr_reader_new_path}']")
  end

  def test_qr_code_link_hidden_for_other_controllers
    stub_controller_name!("names")
    stub_controller_path!("names")

    html = render(top_nav(user: @user))

    assert_no_html(html, "a[href='#{routes.field_slips_qr_reader_new_path}']")
  end

  def test_qr_code_link_hidden_when_user_absent
    html = render(top_nav(user: nil))

    assert_no_html(html, "a[href='#{routes.field_slips_qr_reader_new_path}']")
  end

  # ---- nav-toggles (mobile chrome) ----------------------------------

  def test_left_nav_toggle_renders_with_offcanvas_wiring
    html = render(top_nav(user: @user))

    selector = "button#left_nav_toggle[data-toggle='offcanvas']" \
               "[data-action='nav#toggleOffcanvas']"
    assert_html(html, selector)
    # Logo glyph
    assert_html(html, "#left_nav_toggle img[alt='#{:MENU.t}']")
  end

  def test_search_nav_toggle_renders_with_collapse_wiring
    html = render(top_nav(user: @user))

    assert_html(html,
                "button[data-toggle='collapse'][data-target='#search_nav']")
  end

  # ---- Login / UserNav slot -----------------------------------------

  def test_renders_login_when_user_absent
    html = render(top_nav(user: nil))

    # Login slot leaves the dropdown out, renders "Login" / "Signup"
    # buttons.
    assert_html(html, "a#user_nav_login_link",
                text: :app_login.l.as_displayed)
    assert_html(html, "a#user_nav_signup_link",
                text: :app_create_account.l.as_displayed)
  end

  def test_renders_user_nav_when_user_present
    html = render(top_nav(user: @user))

    # UserNav dropdown shows the user's login name as the toggle.
    assert_html(html, "a.dropdown-toggle", text: @user.login)
  end

  private

  def top_nav(user:, query: nil)
    TopNavWithoutSearchRow.new(user: user, query: query)
  end

  # Override controller_name on the test controller so methods like
  # `nav_create_visible?` see "observations" instead of the default
  # "test". `ControllerLabels` (included via
  # `ComponentTestCase::TEST_CONTROLLER_MODULES`) derives
  # `controller_model_name` / `rubric` from `controller_name`, and
  # filters `ActionView::TestCase::TestController`'s module parent
  # so `parent_controller_module` already returns nil — no extra
  # stubs needed for any of those.
  def stub_controller_name!(name)
    controller.define_singleton_method(:controller_name) { name }
  end

  def stub_controller_path!(path)
    controller.define_singleton_method(:controller_path) { path }
  end

  # Make controller.methods.include?(:new) return what the test wants.
  # `nav_create_visible?` reads `methods.include?(:new)`; the test
  # controller doesn't actually define a `new` action by default.
  def define_action_methods!(actions)
    list = actions.map(&:to_sym)
    controller.define_singleton_method(:methods) do |*args|
      super(*args) | list
    end
  end

  def define_singleton_action_name!(action)
    controller.define_singleton_method(:action_name) { action }
  end
end
