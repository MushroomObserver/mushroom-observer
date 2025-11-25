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
end
