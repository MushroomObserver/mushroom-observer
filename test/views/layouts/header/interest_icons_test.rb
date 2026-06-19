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
      assert_html(html, "img.interest_small[src*='watch3']")
      assert_html(html, "img.interest_small[src*='ignore3']")
      # No big icon in default state.
      assert_no_html(html, "img.interest_big")
    end

    def test_default_state_links_set_to_watch_or_ignore
      html = render_view

      assert_html(html,
                  "a[href='#{routes.set_interest_path(
                    id: @obs.id, type: "Observation", state: 1
                  )}'] img[src*='watch3']")
      assert_html(html,
                  "a[href='#{routes.set_interest_path(
                    id: @obs.id, type: "Observation", state: -1
                  )}'] img[src*='ignore3']")
    end

    # ---- watching state -------------------------------------------

    def test_watching_state_renders_big_watch_plus_two_small
      ::Interest.create!(user: @viewer, target: @obs, state: true)

      html = render_view

      assert_html(html, "img.interest_big[src*='watch2']")
      assert_html(html, "img.interest_small[src*='halfopen3']")
      assert_html(html, "img.interest_small[src*='ignore3']")
    end

    def test_watching_state_small_icon_states
      ::Interest.create!(user: @viewer, target: @obs, state: true)

      html = render_view

      # halfopen → default (state: 0), ignore → ignoring (state: -1).
      assert_html(html,
                  "a[href='#{routes.set_interest_path(
                    id: @obs.id, type: "Observation", state: 0
                  )}'] img[src*='halfopen3']")
      assert_html(html,
                  "a[href='#{routes.set_interest_path(
                    id: @obs.id, type: "Observation", state: -1
                  )}'] img[src*='ignore3']")
    end

    # ---- ignoring state -------------------------------------------

    def test_ignoring_state_renders_big_ignore_plus_two_small
      ::Interest.create!(user: @viewer, target: @obs, state: false)

      html = render_view

      assert_html(html, "img.interest_big[src*='ignore2']")
      assert_html(html, "img.interest_small[src*='watch3']")
      assert_html(html, "img.interest_small[src*='halfopen3']")
    end

    def test_ignoring_state_small_icon_states
      ::Interest.create!(user: @viewer, target: @obs, state: false)

      html = render_view

      # watch → watching (state: 1), halfopen → default (state: 0).
      assert_html(html,
                  "a[href='#{routes.set_interest_path(
                    id: @obs.id, type: "Observation", state: 1
                  )}'] img[src*='watch3']")
      assert_html(html,
                  "a[href='#{routes.set_interest_path(
                    id: @obs.id, type: "Observation", state: 0
                  )}'] img[src*='halfopen3']")
    end

    # ---- Turbo wiring ---------------------------------------------

    def test_all_links_get_data_turbo_stream_attribute
      html = render_view

      doc = Nokogiri::HTML(html)
      anchors = doc.css("a")
      assert_operator(anchors.size, :>=, 2,
                      "Expected at least two interest links")
      anchors.each do |a|
        assert_equal("true", a["data-turbo-stream"],
                     "Every interest link should opt into turbo-stream")
      end
    end

    private

    def render_view
      render(Header::InterestIcons.new(user: @viewer, object: @obs))
    end
  end
end
