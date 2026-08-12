# frozen_string_literal: true

require("test_helper")

# Contract tests for `Views::Layouts::Header::InterestIcons` — the
# three-icon block on a show page's title bar (watching / ignoring /
# default) that lets the viewer subscribe to email alerts.
module Views::Layouts
  class Header::InterestIconsTest < ComponentTestCase
    def setup
      super
      @viewer = users(:rolf)
      @obs = observations(:detailed_unknown_obs)
      ::Interest.where(user: @viewer, target: @obs).destroy_all
    end

    # ---- default state (no interest set) ---------------------------

    def test_default_state_renders_two_small_icons
      html = render_view

      assert_html(html, "ul.interest-eyes")
      # Default: small watch (→ start watching) + small ignore (→ ignore).
      assert_html(html, "img.mo-icon[src*='watch3']")
      assert_html(html, "img.mo-icon[src*='ignore3']")
      # No big state-indicator icon (disabled span) in default state.
      assert_no_html(html, "span.disabled img")
    end

    def test_default_state_links_are_create_posts_with_id_and_state
      html = render_view

      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(1) " \
                  "form[action='#{routes.interests_path}'][method='post'] " \
                  "input[name='id'][value='#{@obs.id}']")
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(1) " \
                  "input[name='state'][value='1']")
      assert_html(html, "ul.interest-eyes li:nth-of-type(1) img[src*='watch3']")
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(2) " \
                  "form[action='#{routes.interests_path}'][method='post'] " \
                  "input[name='state'][value='-1']")
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(2) img[src*='ignore3']")
    end

    # ---- watching state -------------------------------------------

    def test_watching_state_renders_big_watch_plus_two_small
      ::Interest.create!(user: @viewer, target: @obs, state: true)

      html = render_view

      assert_html(html, "span.disabled img.mo-icon[src*='watch2']")
      assert_html(html, "img.mo-icon[src*='halfopen3']")
      assert_html(html, "img.mo-icon[src*='ignore3']")
    end

    def test_watching_state_small_icon_states
      ::Interest.create!(user: @viewer, target: @obs, state: true)

      html = render_view
      obs_path = routes.interest_path(@obs.id)

      # halfopen → DELETE (destroy the Interest row outright).
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(2) " \
                  "form[action='#{obs_path}'] " \
                  "input[name='_method'][value='delete']")
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(2) img[src*='halfopen3']")
      assert_no_html(html,
                     "ul.interest-eyes li:nth-of-type(2) input[name='id']")
      # ignore → PATCH (update the existing row to state: -1).
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(3) " \
                  "form[action='#{obs_path}'] " \
                  "input[name='_method'][value='patch']")
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(3) " \
                  "input[name='state'][value='-1']")
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(3) img[src*='ignore3']")
    end

    # ---- ignoring state -------------------------------------------

    def test_ignoring_state_renders_big_ignore_plus_two_small
      ::Interest.create!(user: @viewer, target: @obs, state: false)

      html = render_view

      assert_html(html, "span.disabled img.mo-icon[src*='ignore2']")
      assert_html(html, "img.mo-icon[src*='watch3']")
      assert_html(html, "img.mo-icon[src*='halfopen3']")
    end

    def test_ignoring_state_small_icon_states
      ::Interest.create!(user: @viewer, target: @obs, state: false)

      html = render_view
      obs_path = routes.interest_path(@obs.id)

      # watch → PATCH (update the existing row to state: 1).
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(2) " \
                  "form[action='#{obs_path}'] " \
                  "input[name='_method'][value='patch']")
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(2) " \
                  "input[name='state'][value='1']")
      assert_html(html, "ul.interest-eyes li:nth-of-type(2) img[src*='watch3']")
      # halfopen → DELETE (destroy the Interest row outright).
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(3) " \
                  "form[action='#{obs_path}'] " \
                  "input[name='_method'][value='delete']")
      assert_html(html,
                  "ul.interest-eyes li:nth-of-type(3) img[src*='halfopen3']")
    end

    # ---- li structure (regression: two links were in one <li>) ----

    def test_default_state_each_link_in_own_li
      html = render_view

      assert_html(html, "ul.interest-eyes > li", count: 2)
      assert_html(html, "ul.interest-eyes li form", count: 2)
    end

    def test_watching_state_each_link_in_own_li
      ::Interest.create!(user: @viewer, target: @obs, state: true)
      html = render_view

      # icon_li (big watch, no form) + two button lis.
      assert_html(html, "ul.interest-eyes > li", count: 3)
      assert_html(html, "ul.interest-eyes li form", count: 2)
    end

    def test_ignoring_state_each_link_in_own_li
      ::Interest.create!(user: @viewer, target: @obs, state: false)
      html = render_view

      assert_html(html, "ul.interest-eyes > li", count: 3)
      assert_html(html, "ul.interest-eyes li form", count: 2)
    end

    # ---- kind class -> image mapping --------------------------------
    #
    # The single source of truth for "interest_watch/interest_ignore/
    # interest_halfopen means this image" -- controller-level show-page
    # tests (observations/names/locations) assert only the class, via
    # `ControllerExtensions#assert_interest_button_in_html`, so they
    # don't need to change if this ever moves off .png (e.g. to the
    # SVG sprite).

    def test_watch_class_matches_watch_images
      html = render_view

      assert_html(html, "img.interest_watch[src*='watch3']")
      ::Interest.create!(user: @viewer, target: @obs, state: true)
      assert_html(render_view, "img.interest_watch[src*='watch2']")
    end

    def test_ignore_class_matches_ignore_images
      html = render_view

      assert_html(html, "img.interest_ignore[src*='ignore3']")
      ::Interest.create!(user: @viewer, target: @obs, state: false)
      assert_html(render_view, "img.interest_ignore[src*='ignore2']")
    end

    def test_halfopen_class_matches_halfopen_image
      ::Interest.create!(user: @viewer, target: @obs, state: true)

      assert_html(render_view, "img.interest_halfopen[src*='halfopen3']")
    end

    # ---- Turbo wiring ---------------------------------------------

    def test_all_buttons_get_data_turbo_stream_attribute
      html = render_view

      doc = Nokogiri::HTML(html)
      buttons = doc.css("ul.interest-eyes button")
      assert_equal(2, buttons.size, "Expected exactly two interest buttons")
      buttons.each do |button|
        assert_equal("true", button["data-turbo-stream"],
                     "Every interest button should opt into turbo-stream")
      end
    end

    private

    def render_view
      render(Header::InterestIcons.new(user: @viewer, object: @obs))
    end
  end
end
