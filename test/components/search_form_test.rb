# frozen_string_literal: true

require "test_helper"

class SearchFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @query = Query::Observations.new
    controller.request = ActionDispatch::TestRequest.create
    # Use real search controller from the app
    @search_controller = ::Observations::SearchController.new
  end

  def test_renders_form_with_correct_action
    html = render_form

    assert_html(html, "form[action='/observations/search']")
    assert_html(html, "form[method='post']")
  end

  def test_renders_form_with_correct_id
    html = render_form

    assert_html(html, "form#observations_search_form")
  end

  # When local (on a search page), form should NOT use turbo_stream
  def test_form_no_turbo_stream_when_local
    html = render_form(local: true)
    doc = Nokogiri::HTML(html)

    form = doc.at_css("form#observations_search_form")
    assert(form, "Should have form")
    assert_nil(form["data-turbo-stream"],
               "Form should NOT have data-turbo-stream when local")
  end

  # When not local (in nav dropdown), form SHOULD use turbo_stream
  # for future in-place result updates
  def test_form_uses_turbo_stream_when_not_local
    html = render_form(local: false)
    doc = Nokogiri::HTML(html)

    form = doc.at_css("form#observations_search_form")
    assert(form, "Should have form")
    assert_equal("true", form["data-turbo-stream"],
                 "Form should have data-turbo-stream='true' when not local")
  end

  def test_renders_panels_for_field_columns
    html = render_form

    # Should have panels based on FIELD_COLUMNS
    assert_html(html, ".panel")
  end

  def test_renders_submit_button
    html = render_form

    assert_html(html, "input[type='submit']")
    assert_html(html, "input[value='#{:SEARCH.l}']")
  end

  def test_renders_clear_button
    html = render_form

    assert_html(html, "a.clear-button", text: :CLEAR.l)
  end

  # When local (on a search page), clear button should NOT use turbo_stream
  # because #search_nav_form doesn't exist on search pages
  def test_clear_button_no_turbo_stream_when_local
    html = render_form(local: true)
    doc = Nokogiri::HTML(html)

    clear_btn = doc.at_css("a.clear-button")
    assert(clear_btn, "Should have clear button")
    assert_nil(clear_btn["data-turbo-stream"],
               "Clear button should NOT have data-turbo-stream when local")
    assert_match(%r{/search/new\?clear=true}, clear_btn["href"],
                 "Clear button should link to search/new with clear param")
  end

  # When not local (in nav dropdown), clear button SHOULD use turbo_stream
  # to update #search_nav_form without full page reload
  def test_clear_button_uses_turbo_stream_when_not_local
    html = render_form(local: false)
    doc = Nokogiri::HTML(html)

    clear_btn = doc.at_css("a.clear-button")
    assert(clear_btn, "Should have clear button")
    assert_equal("true", clear_btn["data-turbo-stream"],
                 "Clear button needs data-turbo-stream when not local")
  end

  def test_renders_header_when_not_local
    html = render_form(local: false)

    assert_html(html, ".navbar-flex")
    assert_html(html, "body",
                text: :search_form_title.t(type: :OBSERVATIONS))
  end

  def test_does_not_render_header_when_local
    html = render_form(local: true)
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css(".navbar-flex"),
               "Expected NOT to find element matching '.navbar-flex'")
  end

  def test_names_search_form_has_correct_field_ids
    query = Query::Names.new
    search_controller = ::Names::SearchController.new
    form = Components::SearchForm.new(
      query,
      search_controller: search_controller,
      local: true,
      form_action_url: "/names/search"
    )
    html = render(form)

    assert_html(html, "#query_names_names_lookup")
    assert_html(html, "#query_names_names_include_synonyms")
    assert_html(html, "#query_names_has_author")
    assert_html(html, "#query_names_misspellings")

    # Verify has_author has correct option values
    doc = Nokogiri::HTML(html)
    has_author_select = doc.at_css("#query_names_has_author")
    yes_option = has_author_select.at_css("option[value='true']")
    assert(yes_option, "has_author should have option with value='true'")
    assert_equal("yes", yes_option.text)

    # Verify misspellings has correct option values: [:no, :include, :only]
    misspellings_select = doc.at_css("#query_names_misspellings")
    assert(misspellings_select, "Should have misspellings select")
    no_option = misspellings_select.at_css("option[value='no']")
    include_option = misspellings_select.at_css("option[value='include']")
    only_option = misspellings_select.at_css("option[value='only']")
    assert(no_option, "misspellings should have option with value='no'")
    assert(include_option,
           "misspellings should have option with value='include'")
    assert(only_option, "misspellings should have option with value='only'")
    # Should NOT have 'yes' option (that was a bug)
    yes_option = misspellings_select.at_css("option[value='yes']")
    assert_nil(yes_option, "misspellings should NOT have 'yes' option")
  end

  # TDD test: Verify search form prefills fields from existing query
  def test_names_lookup_fields_prefilled_from_query
    agaricus = names(:agaricus)
    query = Query::Observations.new
    query.names = {
      lookup: [agaricus.id],
      include_subtaxa: true,
      include_synonyms: true
    }

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # The text input should show the name
    lookup_input = doc.at_css("#query_observations_names_lookup")
    assert(lookup_input, "Should have names lookup input")
    assert_equal(agaricus.display_name, lookup_input["value"],
                 "Lookup input should be prefilled with name")

    # The hidden ID field should have the ID
    hidden_id = doc.at_css("#query_observations_names_lookup_id")
    assert(hidden_id, "Should have hidden ID field")
    assert_equal(agaricus.id.to_s, hidden_id["value"],
                 "Hidden ID field should be prefilled with name ID")

    # The modifier fields should be selected
    include_subtaxa = doc.at_css("#query_observations_names_include_subtaxa")
    assert(include_subtaxa, "Should have include_subtaxa select")
    selected_option = include_subtaxa.at_css("option[selected]")
    assert(selected_option, "include_subtaxa should have selected option")
    assert_equal("true", selected_option["value"],
                 "include_subtaxa should be selected as 'true'")

    include_synonyms = doc.at_css("#query_observations_names_include_synonyms")
    assert(include_synonyms, "Should have include_synonyms select")
    selected_option = include_synonyms.at_css("option[selected]")
    assert(selected_option, "include_synonyms should have selected option")
    assert_equal("true", selected_option["value"],
                 "include_synonyms should be selected as 'true'")
  end

  # TDD test: Verify modifier collapse is expanded when modifiers have values
  def test_names_lookup_modifier_collapse_expanded_when_prefilled
    agaricus = names(:agaricus)
    query = Query::Observations.new
    query.names = {
      lookup: [agaricus.id],
      include_subtaxa: true
    }

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # The collapse div should have class "in" to be expanded
    selector = "[data-autocompleter--name-target='collapseFields']"
    collapse_div = doc.at_css(selector)
    assert(collapse_div, "Should have collapse div for modifier fields")
    assert_includes(collapse_div["class"], "in",
                    "Collapse div should have 'in' class when modifiers " \
                    "have values")
  end

  # TDD test: Panel collapse should be expanded when collapsed field has value
  def test_panel_collapse_expanded_when_collapsed_field_prefilled
    query = Query::Observations.new
    # created_at is in the "dates" panel's collapsed section
    query.created_at = "2024-01-01"

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # The dates panel's collapse div should have class "in"
    collapse_div = doc.at_css("#observations_dates.panel-collapse")
    assert(collapse_div, "Should have dates panel collapse div")
    assert_includes(collapse_div["class"], "in",
                    "Panel collapse should have 'in' class when collapsed " \
                    "field has value")
  end

  # TDD test: Panel collapse should NOT be expanded when no collapsed fields
  def test_panel_collapse_not_expanded_when_no_collapsed_fields_prefilled
    query = Query::Observations.new
    # Only set a "shown" field, not a collapsed one
    # date is in the "dates" panel's shown section
    query.date = "2024-01-01"

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # The dates panel's collapse div should NOT have class "in"
    collapse_div = doc.at_css("#observations_dates.panel-collapse")
    assert(collapse_div, "Should have dates panel collapse div")
    assert_not_includes(collapse_div["class"].to_s, "in",
                        "Panel collapse should NOT have 'in' class when only " \
                        "shown fields are set")
  end

  # TDD test: Modifier collapse should be expanded when lookup has value
  # (even if no modifier fields are set)
  def test_names_lookup_modifier_collapse_expanded_when_lookup_has_value
    agaricus = names(:agaricus)
    query = Query::Observations.new
    query.names = {
      lookup: [agaricus.id]
      # No modifier fields set, but lookup has a value
    }

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # The collapse div SHOULD have class "in" because lookup has a value
    selector = "[data-autocompleter--name-target='collapseFields']"
    collapse_div = doc.at_css(selector)
    assert(collapse_div, "Should have collapse div for modifier fields")
    assert_includes(collapse_div["class"], "in",
                    "Collapse div should have 'in' class when lookup " \
                    "has a value")
  end

  # TDD test: Modifier collapse NOT expanded when names hash is empty
  def test_names_lookup_modifier_collapse_not_expanded_when_names_empty
    query = Query::Observations.new
    # Don't set any names at all

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # The collapse div should NOT have class "in"
    selector = "[data-autocompleter--name-target='collapseFields']"
    collapse_div = doc.at_css(selector)
    assert(collapse_div, "Should have collapse div for modifier fields")
    assert_not_includes(collapse_div["class"].to_s, "in",
                        "Collapse div should NOT have 'in' class when " \
                        "names is empty")
  end

  # TDD test: by_users hidden field should have correct name for controller
  # The controller expects `by_users_id`, not `user_id`
  def test_by_users_hidden_field_has_correct_name
    html = render_form

    doc = Nokogiri::HTML(html)
    hidden_field = doc.at_css("input[type='hidden'][name*='by_users_id']")

    assert(hidden_field,
           "by_users autocompleter should have hidden field " \
           "query_observations[by_users_id], not [user_id]")
  end

  # NOTE: render_select_no_eq_nil_or_yes was removed as dead code.
  # The :select_no_eq_nil_or_yes style (used for include_synonyms, etc.)
  # is rendered by NamesLookupFieldGroup, not SearchForm directly.
  # See test/components/names_lookup_field_group_test.rb for coverage.

  def test_field_label_uses_query_translation
    # date is a valid Observations field in the "shown" section
    html = render_form

    # Should use :"query_#{field_name}".l.humanize for labels
    doc = Nokogiri::HTML(html)
    label = doc.at_css("label[for='query_observations_date']")
    assert(label, "Should have date label")
    assert_equal(:query_date.l.humanize, label.text.strip)
  end

  def test_date_field_prefills_string_value
    query = Query::Observations.new(date: "2024-01-15")
    html = render_form_with_query(query)

    doc = Nokogiri::HTML(html)
    input = doc.at_css("#query_observations_date")
    assert(input, "Should have date input")
    assert_equal("2024-01-15", input["value"])
  end

  def test_date_field_joins_array_for_range
    # Date ranges are stored as arrays: ["start", "end"]
    query = Query::Observations.new
    query.date = %w[2021-01-06 2021-01-15]
    html = render_form_with_query(query)

    doc = Nokogiri::HTML(html)
    input = doc.at_css("#query_observations_date")
    assert(input, "Should have date input")
    assert_equal("2021-01-06-2021-01-15", input["value"])
  end

  # Cover NamesLookupFieldGroup bool_to_string false branch (line 160)
  def test_names_modifier_prefilled_with_false
    agaricus = names(:agaricus)
    query = Query::Observations.new
    query.names = {
      lookup: [agaricus.id],
      include_synonyms: false
    }

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    include_synonyms = doc.at_css("#query_observations_names_include_synonyms")
    assert(include_synonyms, "Should have include_synonyms select")
    selected_option = include_synonyms.at_css("option[selected]")
    # When false, the "no" option (value="") should NOT be selected,
    # but we need to verify false is handled
    assert_nil(selected_option,
               "include_synonyms=false should not select any option " \
               "(no option has value='false')")
  end

  # Cover NamesLookupFieldGroup prefill_via_id rescue branch (line 80)
  def test_names_lookup_with_unknown_id_passes_through
    unknown_id = 999_999_999
    query = Query::Observations.new
    query.names = { lookup: [unknown_id] }

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    lookup_input = doc.at_css("#query_observations_names_lookup")
    assert(lookup_input, "Should have names lookup input")
    # Unknown ID should pass through as-is
    assert_equal(unknown_id.to_s, lookup_input["value"])
  end

  # Cover NamesLookupFieldGroup modifiers_have_values? (lines 106-107)
  # This is called when lookup is empty but modifiers have values
  def test_collapse_expanded_when_only_modifier_has_value
    query = Query::Observations.new
    # No lookup, but modifier has value
    query.names = { include_synonyms: true }

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # Collapse should be expanded because modifier has value
    selector = "[data-autocompleter--name-target='collapseFields']"
    collapse_div = doc.at_css(selector)
    assert(collapse_div, "Should have collapse div")
    assert_includes(collapse_div["class"], "in",
                    "Collapse should be expanded when modifier has value")
  end

  # Rank range with only the second value set should use minimum as first value
  # Bug: ["", "Species"] should be parsed as ["Form", "Species"] (Form is min)
  # Note: rank is a Names query field, not Observations
  def test_rank_range_with_blank_first_value_uses_minimum
    query = Query::Names.new
    # Simulate user selecting blank first, "Species" second
    query.rank = ["", "Species"]

    search_controller = ::Names::SearchController.new
    form = Components::SearchForm.new(
      query,
      search_controller: search_controller,
      local: true,
      form_action_url: "/names/search"
    )
    html = render(form)
    doc = Nokogiri::HTML(html)

    # First select should have "Form" selected (the minimum rank)
    rank_select = doc.at_css("#query_names_rank")
    assert(rank_select, "Should have rank select")
    selected = rank_select.at_css("option[selected]")
    assert(selected, "First rank select should have a selected option")
    assert_equal("Form", selected["value"],
                 "First rank should default to minimum 'Form' when blank")

    # Second select should have "Species" selected
    rank_range_select = doc.at_css("#query_names_rank_range")
    assert(rank_range_select, "Should have rank_range select")
    selected_range = rank_range_select.at_css("option[selected]")
    assert(selected_range, "Second rank select should have selected option")
    assert_equal("Species", selected_range["value"])
  end

  # Confidence range with only the second value set should use minimum as first
  # Bug: [nil, 2.0] should be parsed as [-3.0, 2.0] (-3.0 is min confidence)
  def test_confidence_range_with_blank_first_value_uses_minimum
    query = Query::Observations.new
    # Simulate user selecting blank first, "Promising" (2.0) second
    query.confidence = [nil, 2.0]

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # First select should have -3.0 selected (the minimum confidence)
    confidence_select = doc.at_css("#query_observations_confidence")
    assert(confidence_select, "Should have confidence select")
    selected = confidence_select.at_css("option[selected]")
    assert(selected, "First confidence select should have a selected option")
    assert_equal("-3.0", selected["value"],
                 "First confidence should default to minimum -3.0 when blank")

    # Second select should have 2.0 selected
    confidence_range_select = doc.at_css("#query_observations_confidence_range")
    assert(confidence_range_select, "Should have confidence_range select")
    selected_range = confidence_range_select.at_css("option[selected]")
    assert(selected_range,
           "Second confidence select should have selected option")
    assert_equal("2.0", selected_range["value"])
  end

  # Rank with first value set, second blank = exact match (leave second blank)
  def test_rank_range_with_blank_second_value_stays_blank
    query = Query::Names.new
    query.rank = ["Species", ""]

    search_controller = ::Names::SearchController.new
    form = Components::SearchForm.new(
      query,
      search_controller: search_controller,
      local: true,
      form_action_url: "/names/search"
    )
    html = render(form)
    doc = Nokogiri::HTML(html)

    # First select should have "Species" selected
    rank_select = doc.at_css("#query_names_rank")
    assert(rank_select, "Should have rank select")
    selected = rank_select.at_css("option[selected]")
    assert(selected, "First rank select should have a selected option")
    assert_equal("Species", selected["value"])

    # Second select should have the blank option selected (exact match)
    rank_range_select = doc.at_css("#query_names_rank_range")
    assert(rank_range_select, "Should have rank_range select")
    selected_range = rank_range_select.at_css("option[selected]")
    assert(selected_range,
           "Second rank should have blank option selected")
    assert_empty(selected_range.text,
                 "Second rank should be blank for exact match")
  end

  # Confidence with first value set, second blank = single value
  # (scope handles range)
  def test_confidence_single_positive_value_stays_single
    query = Query::Observations.new
    query.confidence = [2.0]

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # First select should have 2.0 selected
    confidence_select = doc.at_css("#query_observations_confidence")
    assert(confidence_select, "Should have confidence select")
    selected = confidence_select.at_css("option[selected]")
    assert(selected, "First confidence select should have selected option")
    assert_equal("2.0", selected["value"])

    # Second select should have blank option selected (single value,
    # not a range)
    confidence_range_select = doc.at_css("#query_observations_confidence_range")
    assert(confidence_range_select, "Should have confidence_range select")
    selected_range = confidence_range_select.at_css("option[selected]")
    assert(selected_range,
           "Second confidence select should have an option selected")
    assert_equal(
      "", selected_range["value"].to_s,
      "Second confidence should have blank value for single value search"
    )
  end

  # Negative confidence single value stays single
  def test_confidence_single_negative_value_stays_single
    query = Query::Observations.new
    query.confidence = [-1.0]

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # First select should have -1.0 selected
    confidence_select = doc.at_css("#query_observations_confidence")
    assert(confidence_select, "Should have confidence select")
    selected = confidence_select.at_css("option[selected]")
    assert(selected, "First confidence select should have selected option")
    assert_equal("-1.0", selected["value"])

    # Second select should have blank option selected (single value,
    # not a range)
    confidence_range_select = doc.at_css("#query_observations_confidence_range")
    assert(confidence_range_select, "Should have confidence_range select")
    selected_range = confidence_range_select.at_css("option[selected]")
    assert(selected_range,
           "Second confidence select should have an option selected")
    assert_equal(
      "", selected_range["value"].to_s,
      "Second confidence should have blank value for single value search"
    )
  end

  # "No Opinion" (0) should not be filled with maximum - exact match only
  def test_confidence_no_opinion_stays_single_value
    query = Query::Observations.new
    query.confidence = [0.0]

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # First select should have 0 (No Opinion) selected
    confidence_select = doc.at_css("#query_observations_confidence")
    assert(confidence_select, "Should have confidence select")
    selected = confidence_select.at_css("option[selected]")

    # Debug: print all options if test fails
    unless selected
      puts("\n=== DEBUG: First dropdown options ===")
      confidence_select.css("option").each do |opt|
        puts("  value=#{opt["value"].inspect}, " \
             "selected=#{opt["selected"].inspect}, text=#{opt.text}")
      end
    end

    assert(selected, "First confidence select should have selected option")
    assert_equal("0", selected["value"],
                 "First confidence should be 0 (No Opinion)")

    # Second select should have blank/nil option selected (exact match,
    # not a range)
    confidence_range_select = doc.at_css("#query_observations_confidence_range")
    assert(confidence_range_select, "Should have confidence_range select")
    # The blank option should be selected
    selected_range = confidence_range_select.at_css("option[selected]")
    assert(selected_range,
           "Second confidence select should have an option selected")
    assert_equal(
      "", selected_range["value"].to_s,
      "Second confidence should have blank value for No Opinion (exact match)"
    )
  end

  # Cover RegionWithBoxFields box_value and build_minimal_location
  # when in_box has values (lines 114, 130, 132)
  def test_region_fields_prefilled_with_box_values
    query = Query::Observations.new
    query.in_box = { north: 45.0, south: 40.0, east: -70.0, west: -80.0 }

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # Check that box inputs have prefilled values
    north_input = doc.at_css("input[name*='north']")
    assert(north_input, "Should have north input")
    assert_equal("45.0", north_input["value"])

    south_input = doc.at_css("input[name*='south']")
    assert(south_input, "Should have south input")
    assert_equal("40.0", south_input["value"])
  end

  # Test array_to_newlines with array value (line 422)
  def test_textarea_field_with_array_value_joins_with_newlines
    query = Query::Observations.new
    query.has_notes_fields = %w[Substrate Cap_Color]

    html = render_form_with_query(query)

    # The value should be joined with newlines
    assert_includes(html, "Substrate\nCap_Color")
  end

  private

  def render_form(local: true)
    form = Components::SearchForm.new(
      @query,
      search_controller: @search_controller,
      local: local,
      form_action_url: "/observations/search"
    )
    render(form)
  end

  def render_form_with_query(query)
    form = Components::SearchForm.new(
      query,
      search_controller: @search_controller,
      local: true,
      form_action_url: "/observations/search"
    )
    render(form)
  end
end
