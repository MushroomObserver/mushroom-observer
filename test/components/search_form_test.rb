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
    collapse_div = doc.at_css("[data-autocompleter-target='collapseFields']")
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

  # TDD test: Verify modifier collapse is NOT expanded when modifiers empty
  def test_names_lookup_modifier_collapse_not_expanded_when_empty
    agaricus = names(:agaricus)
    query = Query::Observations.new
    query.names = {
      lookup: [agaricus.id]
      # No modifier fields set
    }

    html = render_form_with_query(query)
    doc = Nokogiri::HTML(html)

    # The collapse div should NOT have class "in"
    collapse_div = doc.at_css("[data-autocompleter-target='collapseFields']")
    assert(collapse_div, "Should have collapse div for modifier fields")
    assert_not_includes(collapse_div["class"].to_s, "in",
                        "Collapse div should NOT have 'in' class when " \
                        "modifiers are empty")
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
