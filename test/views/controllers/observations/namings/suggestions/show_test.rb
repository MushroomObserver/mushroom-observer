# frozen_string_literal: true

require("test_helper")

# Exercises the `Suggestions::Show` Phlex view branches that the
# legacy `suggestions_controller_test` couldn't reach — it passed
# raw probabilities (0.7654) but `Suggestion#confident?` /
# `#useless?` thresholds are 50 / 5 (percentages). Decimal probs
# made every suggestion useless and the column rendered empty;
# the test passed anyway because it only asserted on the
# `@suggestions` ivar.
module Views::Controllers::Observations::Namings::Suggestions
  class ShowTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      @observation = observations(:detailed_unknown_obs)
    end

    def test_renders_confident_and_others_groups_with_proposed_links
      # Build two suggestions: one confident (>= 50%), one not
      # (still > 5% so not useless). One should land in the
      # "Confident" table, the other in "Other Suggestions".
      confident = ::Suggestion.new("Coprinus comatus", 80)
      borderline = ::Suggestion.new("Agrocybe arvalis", 25)

      html = render(Show.new(observation: @observation, user: @user,
                             suggestions: [confident, borderline]))

      # Two `<h3>` section headings, one per group.
      assert_html(html, "h3", count: 2)
      # One propose link per suggestion (each picks up the
      # `new_observation_naming_path` for its name).
      assert_html(html,
                  "a[href*='#{routes.new_observation_naming_path(
                    @observation.id
                  )}']", count: 2)
      assert_includes(html, :suggestions_propose_name.t)
    end

    def test_already_proposed_suggestion_shows_notice_instead_of_link
      # The fixture obs already has a naming for this name —
      # `already_proposed?` returns true so the "already proposed"
      # notice replaces the propose link.
      existing_name = @observation.namings.first.name
      sugg = ::Suggestion.new(existing_name.text_name, 80)

      html = render(Show.new(observation: @observation, user: @user,
                             suggestions: [sugg]))

      assert_includes(html, :suggestions_already_proposed.t)
      assert_no_html(html, "a[href*='new_observation_naming']")
    end

    def test_useless_suggestions_are_filtered_out
      # `useless?` removes anything below 5% — neither group
      # renders so no `<h3>` heading appears.
      useless = ::Suggestion.new("Coprinus comatus", 3)

      html = render(Show.new(observation: @observation, user: @user,
                             suggestions: [useless]))

      assert_no_html(html, "h3")
    end

    def test_confidence_lines_show_avg_when_observation_has_multiple_images
      # Force multiple images on the obs so `render_confidence_lines`
      # takes the avg branch (max + avg) rather than the
      # single-image one.
      assert_operator(@observation.images.length, :>, 1, "fixture sanity")
      sugg = ::Suggestion.new("Coprinus comatus", 80)

      html = render(Show.new(observation: @observation, user: @user,
                             suggestions: [sugg]))

      assert_includes(html, :suggestions_max.t)
      assert_includes(html, :suggestions_avg.t)
    end

    def test_confidence_lines_show_single_value_when_one_image
      # Single-image observation → `render_confidence_lines` skips
      # the max/avg split and just emits the one confidence value.
      # Assert against the suggestions column to avoid colliding
      # with `Max` / `Avg` text on the obs's image sidebar.
      single_image_obs = observations(:coprinus_comatus_obs)
      assert_equal(1, single_image_obs.images.length, "fixture sanity")
      sugg = ::Suggestion.new("Coprinus comatus", 80)

      html = render(Show.new(observation: single_image_obs, user: @user,
                             suggestions: [sugg]))

      doc = Nokogiri::HTML(html)
      sugg_col = doc.at_css(".obs-suggestions-column")
      assert_not_includes(sugg_col.text, "#{:suggestions_max.t}:")
      assert_not_includes(sugg_col.text, "#{:suggestions_avg.t}:")
    end

    def test_excellent_confidence_label_for_max_above_80
      # `val > 80` branch → "excellent" label inside
      # `suggestion_confidence`. The earlier tests use 80 exactly
      # (which falls into "good"); push above 80 here.
      sugg = ::Suggestion.new("Coprinus comatus", 85)

      html = render(Show.new(observation: @observation, user: @user,
                             suggestions: [sugg]))

      assert_includes(html, :suggestions_excellent.t)
    end
  end
end
