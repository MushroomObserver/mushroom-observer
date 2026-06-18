# frozen_string_literal: true

require("test_helper")

# Tests for `Views::FullPageBase` — the base class for top-level
# action views. Adds the `around_template` hook that wraps the
# action's content in `Views::Layouts::Application` (or `::Printable`
# when `session[:layout] == "printable"`).
#
# Tests use a recording stub layout that captures the props it
# receives + emits the captured inner HTML, so the dispatch +
# prop-forwarding contract is asserted without pulling in every
# sub-component helper chain. End-to-end layout structure is tested
# in `Views::Layouts::ApplicationTest` / `…::PrintableTest`.
class Views::FullPageBaseTest < ComponentTestCase
  # Records the constructed props in a class-level Hash. Emits a
  # `<div class="stub-app">…</div>` wrapper around the captured inner
  # HTML so tests can assert the action's content survives the wrap.
  class RecordingApplication < Components::Base
    CAPTURED = { props: nil, inner: nil }.dup

    prop :canonical_url, _Nilable(::String), default: nil
    prop :any_content_filters_applied, _Nilable(_Boolean), default: nil

    def view_template(&block)
      CAPTURED[:props] = {
        canonical_url: @canonical_url,
        any_content_filters_applied: @any_content_filters_applied
      }
      div(class: "stub-app", &block)
    end
  end

  class RecordingPrintable < Components::Base
    CAPTURED = { invoked: false }.dup

    def view_template(&block)
      CAPTURED[:invoked] = true
      div(class: "stub-printable", &block)
    end
  end

  # Page that swaps in the recording stubs in place of the real
  # `Views::Layouts::Application` / `Printable`. Inherits the dispatch
  # + capture logic from `FullPageBase` unchanged.
  class Page < Views::FullPageBase
    def view_template
      content_for(:document_title, "PageTitle")
      div(id: "page-inner") { plain("PAGE_INNER") }
    end

    private

    def layout_class
      case controller.session[:layout].to_s
      when "printable" then RecordingPrintable
      else RecordingApplication
      end
    end

    def layout_props
      return {} if layout_class == RecordingPrintable

      { canonical_url: ctrl_ivar(:canonical_url),
        any_content_filters_applied: ctrl_ivar(:any_content_filters_applied) }
    end
  end

  def setup
    super
    RecordingApplication::CAPTURED[:props] = nil
    RecordingApplication::CAPTURED[:inner] = nil
    RecordingPrintable::CAPTURED[:invoked] = false
  end

  def test_default_layout_is_application
    stub_session!(layout: "")
    html = render(Page.new)

    assert_html(html, "div.stub-app")
    assert_no_html(html, "div.stub-printable")
  end

  def test_printable_session_picks_printable_layout
    stub_session!(layout: "printable")
    html = render(Page.new)

    assert_html(html, "div.stub-printable")
    assert_no_html(html, "div.stub-app")
    assert(RecordingPrintable::CAPTURED[:invoked])
  end

  def test_unknown_session_layout_falls_back_to_application
    stub_session!(layout: "BOGUS_LAYOUT")
    html = render(Page.new)

    assert_html(html, "div.stub-app")
  end

  def test_capture_emits_action_content_inside_layout
    stub_session!(layout: "")
    html = render(Page.new)

    # The page's `<div id="page-inner">` is captured, then emitted
    # inside the stub layout's wrapper.
    assert_html(html, "div.stub-app > div#page-inner", text: "PAGE_INNER")
  end

  def test_canonical_url_forwarded_from_controller_ivar
    stub_session!(layout: "")
    controller.instance_variable_set(:@canonical_url, "https://test.example/x")
    render(Page.new)

    assert_equal("https://test.example/x",
                 RecordingApplication::CAPTURED[:props][:canonical_url])
  end

  def test_any_content_filters_applied_forwarded_from_controller_ivar
    stub_session!(layout: "")
    controller.instance_variable_set(:@any_content_filters_applied, true)
    render(Page.new)

    assert_equal(true,
                 RecordingApplication::CAPTURED[:props][:any_content_filters_applied])
  end

  def test_ivars_unset_pass_nil
    stub_session!(layout: "")
    render(Page.new)

    assert_nil(RecordingApplication::CAPTURED[:props][:canonical_url])
    assert_nil(RecordingApplication::CAPTURED[:props][:any_content_filters_applied])
  end

  def test_printable_layout_receives_no_application_props
    # `layout_props` returns `{}` when Printable is picked, so the
    # printable layout's constructor takes no kwargs. If the
    # forwarding accidentally passed Application's prop names to
    # Printable's `.new(...)`, this render would raise
    # ArgumentError (Printable has no `canonical_url:` prop).
    stub_session!(layout: "printable")
    controller.instance_variable_set(:@canonical_url, "https://test.example/x")

    render(Page.new) # must not raise

    assert(RecordingPrintable::CAPTURED[:invoked])
  end

  private

  def stub_session!(layout:)
    s = { layout: layout }
    controller.define_singleton_method(:session) { s }
  end
end
