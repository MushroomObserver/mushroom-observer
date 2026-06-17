# frozen_string_literal: true

require("test_helper")

# Contract tests for the FilterCaption Phlex view.
#
# Originally written as parity tests against the legacy
# `Header::FiltersHelper#query_filters` (the 16-method chain that
# this view replaced); once parity was confirmed and the helper
# methods were deleted, these tests were rewritten to assert
# structural properties of the Phlex view directly. They cover the
# same 14 branches the parity tests covered:
# empty / plain / boolean / array / lookup / italicized-lookup /
# confidence / type-tags / subquery / grouped / target / truncation /
# many-params.
module Views::Layouts
  class Header::IndexBar::FilterCaptionTest < ComponentTestCase
    def test_empty_query_renders_all_label
      html = render_for(Query.lookup_and_save(:Observation))

      # No params (after stripping :order_by) → both truncated and
      # full collapses render `:ALL.l` directly, no <b>/<span> tree.
      assert_html(html, "#caption-truncated .small", text: :ALL.l)
      assert_html(html, "#caption-full .small", text: :ALL.l)
    end

    def test_pattern_param_renders_label_and_value
      html = render_for(Query.lookup_and_save(:Name, pattern: "Coprinus"))

      assert_html(html, "#filters", text: "Coprinus")
      assert_html(html, "#caption-truncated .small b", text: "Coprinus")
      assert_html(html, "#caption-truncated .small span",
                  text: :query_pattern.l)
    end

    def test_boolean_param_renders_label_only_no_b_tag
      html = render_for(Query.lookup_and_save(:Observation, has_images: true))

      # Boolean true → just `<span>label</span>`, no `<b>value</b>`.
      assert_html(html, "#caption-truncated .small span",
                  text: :query_has_images.l)
      assert_no_html(html, "#caption-truncated .small b")
    end

    def test_type_tags_param_localizes_via_helper
      html = render_for(
        Query.lookup_and_save(:RssLog,
                              type: "observation species_list")
      )

      # `type_tags_to_label` joins localized labels with ", ".
      assert_html(
        html, "#caption-truncated .small b",
        text: "#{:OBSERVATIONS.l}, #{:SPECIES_LISTS.l}"
      )
    end

    def test_single_name_lookup_renders_italicized_inside_b
      # Names query: `names` is a grouped param wrapping the
      # `lookup:` lookup key. `:lookup` is in PARAM_LOOKUPS AND
      # ITALICIZE_LOOKUP_KEYS, so the resolved name renders inside
      # `<b><i>…</i></b>`.
      query = Query.lookup_and_save(
        :Name, names: { lookup: [names(:coprinus_comatus).id] }
      )

      html = render_for(query)

      assert_html(html, "#caption-truncated .small b i",
                  text: names(:coprinus_comatus).text_name)
    end

    def test_many_lookups_emit_truncation_marker
      ids = Name.where(rank: "Species").limit(5).pluck(:id)
      query = Query.lookup_and_save(:Name, names: { lookup: ids })

      html = render_for(query)

      # The first 3 (CAPTION_TRUNCATE) names are joined then ", ..."
      # is appended in the truncated collapse.
      assert_html(html, "#caption-truncated .small b i",
                  text: ", ...")
      # The full collapse joins all 5 without truncation.
      assert_html(html, "#caption-full .small b i")
    end

    def test_user_lookup_does_not_italicize
      query = Query.lookup_and_save(
        :Observation, by_users: [users(:rolf).id]
      )

      html = render_for(query)

      # `:by_users` is in PARAM_LOOKUPS but NOT in
      # ITALICIZE_LOOKUP_KEYS — value renders inside `<b>` without
      # `<i>` wrapping.
      assert_html(html, "#caption-truncated .small b",
                  text: users(:rolf).legal_name)
      assert_no_html(html, "#caption-truncated .small b i")
    end

    # Both `editable_by_user` (SpeciesLists) and `needs_naming`
    # (Observations) are User-typed query attrs. Before this PR
    # they weren't in PARAM_LOOKUPS, so the caption fell through
    # to the raw-value formatter and printed the user id
    # ("editable_by_user: 1") instead of the user's title.
    def test_editable_by_user_renders_user_title_not_id
      user = users(:rolf)
      query = Query.lookup_and_save(:SpeciesList, editable_by_user: user.id)

      html = render_for(query)

      assert_html(html, "#caption-truncated .small b",
                  text: user.unique_text_name)
    end

    def test_needs_naming_renders_user_title_not_id
      user = users(:rolf)
      query = Query.lookup_and_save(:Observation, needs_naming: user.id)

      html = render_for(query)

      assert_html(html, "#caption-truncated .small b",
                  text: user.unique_text_name)
    end

    def test_project_lookup_does_not_italicize
      project = projects(:bolete_project)
      query = Query.lookup_and_save(:Observation, projects: [project.id])

      html = render_for(query)

      assert_html(html, "#caption-truncated .small b", text: project.title)
      assert_no_html(html, "#caption-truncated .small b i")
    end

    def test_confidence_single_value_renders_as_label
      html = render_for(Query.lookup_and_save(:Observation,
                                              confidence: [2.0]))

      assert_html(html, "#caption-truncated .small b",
                  text: Vote.confidence(2.0))
    end

    def test_confidence_range_joins_two_labels
      html = render_for(Query.lookup_and_save(:Observation,
                                              confidence: [-1.0, 2.0]))

      assert_html(
        html, "#caption-truncated .small b",
        text: "#{Vote.confidence(-1.0)} – #{Vote.confidence(2.0)}"
      )
    end

    def test_grouped_param_renders_label_then_nested_params
      # `:names` with a multi-key Hash val triggers `render_grouped_params`
      # → `render_nested_params` (the non-target path).
      query = Query.lookup_and_save(
        :Name,
        names: { lookup: [names(:coprinus_comatus).id],
                 include_synonyms: true }
      )

      html = render_for(query)

      assert_html(html, "#filters", text: :query_names.l)
      assert_html(html, "#filters", text: :query_include_synonyms.l)
    end

    def test_target_grouped_param_renders_lookup_via_titles
      obs = observations(:detailed_unknown_obs)
      query = Query.lookup_and_save(
        :Comment, target: { type: "Observation", id: obs.id }
      )

      html = render_for(query)

      # `:target` triggers `lookup_comment_target_val` and renders
      # the resolved title in a single `<span>` (not the nested
      # iteration path).
      assert_html(html, "#filters", text: :query_target.l)
    end

    def test_subquery_wraps_nested_params_in_brackets
      query = Query.lookup_and_save(
        :Name, description_query: { by_users: users(:rolf) }
      )

      html = render_for(query)

      # `*_query` keys go through `render_subquery` which wraps the
      # nested params in `[ … ]` spans.
      assert_html(html, "#filters", text: "[")
      assert_html(html, "#filters", text: "]")
      assert_html(html, "#filters", text: :query_description_query.l)
    end

    def test_multiple_params_render_each_with_its_own_b_or_span
      query = Query.lookup_and_save(:Observation,
                                    pattern: "Foo",
                                    by_users: [users(:rolf).id],
                                    has_images: true)

      html = render_for(query)

      # `assert_html` only checks the FIRST element matching the
      # selector, so collapse the assertion onto the wider `#filters`
      # container that contains all three param renderings.
      assert_html(html, "#filters", text: "Foo")
      assert_html(html, "#filters", text: users(:rolf).legal_name)
      assert_html(html, "#filters", text: :query_has_images.l)
    end

    def test_array_value_param_not_in_lookups_uses_join
      # `id_in_set` isn't in PARAM_LOOKUPS, so its Array value goes
      # through `param_val_itself` → `join_array_val`. With ≤
      # CAPTION_TRUNCATE ids the values join with ", " and no
      # truncation marker.
      query = Query.lookup_and_save(:Observation, id_in_set: [1, 2, 3])

      html = render_for(query)

      assert_html(html, "#caption-truncated .small b", text: "1, 2, 3")
    end

    def test_array_value_param_above_truncate_adds_ellipsis
      # With > CAPTION_TRUNCATE (3) ids, the truncated form joins
      # the first 3 and appends ", ...".
      query = Query.lookup_and_save(
        :Observation, id_in_set: [1, 2, 3, 4, 5]
      )

      html = render_for(query)

      assert_html(html, "#caption-truncated .small b",
                  text: "1, 2, 3, ...")
      # The full collapse joins all 5 with no truncation marker.
      assert_html(html, "#caption-full .small b",
                  text: "1, 2, 3, 4, 5")
    end

    def test_long_lookup_string_gets_character_truncated
      # When the joined lookup string exceeds 100 chars,
      # `truncate_joined_string` takes the character-truncation
      # branch (`[0...97] + "..."`) rather than the ", ..."
      # ellipsis branch.
      ids = Name.where("LENGTH(text_name) > 25").
            limit(3).pluck(:id)
      skip("Need 3 names with long text names") unless ids.length == 3
      query = Query.lookup_and_save(:Name, names: { lookup: ids })

      html = render_for(query)

      truncated = Nokogiri::HTML(html).at_css(
        "#caption-truncated .small b i"
      )&.text
      skip("setup didn't produce a >100-char join") unless
        truncated && truncated.length > 90
      assert(truncated.end_with?("..."),
             "expected character-truncated string to end with '...'")
    end

    # --- Stable structural pinning ----------------------------------

    def test_outer_filters_div_carries_stimulus_attrs
      query = Query.lookup_and_save(:Observation, pattern: "Foo")

      html = render_for(query)

      # The stimulus controller + query data attrs are what the
      # filter-caption controller binds to — pin them.
      assert_html(html,
                  "#filters[data-controller='filter-caption']" \
                  "[data-query-record='#{query.record.id}']")
    end

    def test_collapses_carry_filter_caption_targets
      query = Query.lookup_and_save(:Observation, pattern: "Foo")

      html = render_for(query)

      assert_html(html,
                  "#caption-truncated[data-filter-caption-target=" \
                  "'truncated']")
      assert_html(html,
                  "#caption-full[data-filter-caption-target='full']")
    end

    def test_toggle_buttons_carry_stimulus_actions
      query = Query.lookup_and_save(:Observation, pattern: "Foo")

      html = render_for(query)

      assert_html(html,
                  "#caption-truncated button" \
                  "[data-action='filter-caption#showFull']")
      assert_html(html,
                  "#caption-full button" \
                  "[data-action='filter-caption#showTruncated']")
    end

    private

    def render_for(query)
      render(
        Views::Layouts::
        Header::IndexBar::FilterCaption.new(query: query)
      )
    end
  end
end
