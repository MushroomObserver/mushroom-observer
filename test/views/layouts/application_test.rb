# frozen_string_literal: true

require("test_helper")

# Tests for `Views::Layouts::Application` — the default page-chrome
# wrapper that `Views::FullPageBase#around_template` wraps every
# action view in (when `session[:layout]` is not "printable").
#
# Renders via a `FullPageBase` subclass so the test exercises the
# real wrap path (`around_template` → `capture` → render
# `Views::Layouts::Application` with the captured inner HTML). The
# test controller mixes in `ApplicationController::FlashNotices` so
# the real `Views::Layouts::App::PageFlash` renders — flash notices
# flow through the layout, they are not stubbed away.
class Views::Layouts::ApplicationTest < ComponentTestCase
  Browser = Struct.new(:bot?) do
    def bot? = self.[](:bot?)
  end

  class FakePage < Views::FullPageBase
    def view_template
      content_for(:document_title, "FakeTitle")
      div(id: "fake-action-content") { plain("HELLO_INNER") }
    end
  end

  def setup
    super
    @user = users(:rolf)
    @user.update_columns(theme: "BlackOnWhite") if @user.theme.blank?
    stub_request_context!
    stub_controller_state!("observations", "show")
  end

  # ---- Doctype / html / body skeleton --------------------------------

  def test_doctype_and_html_skeleton
    html = render(FakePage.new)

    assert_match(/\A<!doctype html><html\b/, html)
    assert_html(html, "html[class='']")
    assert_html(html, "html > head")
    assert_html(html, "html > body")
  end

  # ---- Head ----------------------------------------------------------

  def test_head_renders_app_head_subcomponent
    html = render(FakePage.new)

    assert_html(html, "head > meta[name='viewport']")
    assert_html(html, "head > meta[name='turbo-prefetch']")
    assert_html(html, "head > meta[property='og:title']")
    assert_html(html, "head > title", text: "FakeTitle")
  end

  def test_canonical_link_emitted_when_controller_sets_ivar
    controller.instance_variable_set(:@canonical_url,
                                     "https://test.example/foo")
    html = render(FakePage.new)

    assert_html(html,
                "head > link[rel='canonical'][href='https://test.example/foo']")
  end

  def test_canonical_link_absent_when_no_ivar
    html = render(FakePage.new)

    assert_no_html(html, "head > link[rel='canonical']")
  end

  # ---- Body class ----------------------------------------------------

  def test_body_class_combines_controller_action_theme_format_login_state
    html = render(FakePage.new)
    body = Nokogiri::HTML5.parse(html).at_css("body")
    classes = body["class"].split

    assert_includes(classes, "observations__show")
    assert_includes(classes, "theme-#{@user.theme.underscore.dasherize}")
    assert_includes(classes, "location-format-postal")
    assert_includes(classes, "logged-in-user")
  end

  def test_body_class_uses_no_user_when_anonymous
    controller.instance_variable_set(:@user, nil)
    html = render(FakePage.new)
    body = Nokogiri::HTML5.parse(html).at_css("body")
    classes = body["class"].split

    assert_includes(classes, "no-user")
    assert_not_includes(classes, "logged-in-user")
  end

  def test_body_class_collapses_create_into_new
    stub_controller_state!("observations", "create")
    html = render(FakePage.new)

    assert_html(html, "body.observations__new")
  end

  def test_body_class_collapses_update_into_edit
    stub_controller_state!("observations", "update")
    html = render(FakePage.new)

    assert_html(html, "body.observations__edit")
  end

  def test_body_carries_lazyload_tooltip_stimulus_controller
    html = render(FakePage.new)

    assert_html(html, "body[data-controller='lazyload tooltip']")
  end

  # ---- Main container + chrome anchors --------------------------------

  def test_main_container_present
    html = render(FakePage.new)

    assert_html(html, "#main_container[data-controller='nav links']")
    assert_html(html, "#main_container[data-nav-target='container']")
  end

  def test_main_emits_action_block_inside
    html = render(FakePage.new)

    assert_html(html, "main#content #fake-action-content",
                text: "HELLO_INNER")
  end

  def test_bottom_singletons_present
    html = render(FakePage.new)

    assert_html(html, "#modal_progress_spinner")
    assert_html(html, "#mo_confirm")
    assert_html(html, "#media_query_tests")
  end

  # ---- Flash notices flow through the layout --------------------------

  def test_page_flash_renders_empty_when_no_notice
    stub_session!(notice: nil, layout: "")
    html = render(FakePage.new)

    assert_html(html, "#page_flash")
    # No flash content — Nokogiri text on #page_flash strips whitespace.
    flash = Nokogiri::HTML5.parse(html).at_css("#page_flash")
    assert_empty(flash.text.strip,
                 "Expected #page_flash to be empty (no session[:notice]); " \
                 "got #{flash.text.strip.inspect}")
  end

  def test_page_flash_renders_notice_when_session_notice_present
    # MO's flash notice encoding: leading digit is the level
    # (0=notice, 1=warning, 2=error), rest is the message.
    stub_session!(notice: "0Hello flash", layout: "")
    html = render(FakePage.new)

    flash = Nokogiri::HTML5.parse(html).at_css("#page_flash")
    assert_includes(flash.text, "Hello flash",
                    "Expected flash text in #page_flash")
  end

  def test_page_flash_renders_warning_at_warning_level
    stub_session!(notice: "1Watch out", layout: "")
    html = render(FakePage.new)

    flash = Nokogiri::HTML5.parse(html).at_css("#page_flash")
    assert_includes(flash.text, "Watch out")
  end

  def test_page_flash_renders_error_at_error_level
    stub_session!(notice: "2It broke", layout: "")
    html = render(FakePage.new)

    flash = Nokogiri::HTML5.parse(html).at_css("#page_flash")
    assert_includes(flash.text, "It broke")
  end

  # ---- Helpers --------------------------------------------------------

  private

  def stub_request_context!
    langs = Language.where.not(beta: true).to_a
    controller.instance_variable_set(:@user, @user)
    controller.instance_variable_set(:@languages, langs)
    stub_session!(layout: "")
  end

  def stub_session!(layout: "", notice: nil)
    s = { layout: layout, notice: notice }
    controller.define_singleton_method(:session) { s }
  end

  # `controller_name`, `controller_path`, `action_name`, and the
  # action methods (`:show`, `:create`, …) drive the layout's body
  # class + TopNav's per-action button visibility. The
  # `ControllerLabels` module (included via
  # `ComponentTestCase::TEST_CONTROLLER_MODULES`) reads
  # `controller_name` to derive `controller_model_name` / `rubric` /
  # `parent_controller_module`, so those don't need their own stubs.
  def stub_controller_state!(name, action)
    controller.define_singleton_method(:controller_name) { name }
    controller.define_singleton_method(:controller_path) { name }
    controller.define_singleton_method(:action_name) { action }
    list = [:index, :show, :new, :edit, :create, :update, :destroy]
    controller.define_singleton_method(:methods) { |*a| super(*a) | list }
  end
end
