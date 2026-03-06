# frozen_string_literal: true

require "test_helper"

class IdentifyFilterFormTest < ComponentTestCase
  def test_renders_default_form
    html = render_component

    # Form structure
    assert_html(html, "form[method='get']")
    assert_html(html, "form[action='/observations/identify']")
    assert_html(html, "form#identify_filter")
    assert_html(html, "form.navbar-form")

    # Default Stimulus controller is clade
    assert_html(html, "form[data-controller='autocompleter--clade']")
    assert_html(html, "form[data-type='clade']")

    # Autocompleter wrap with dual targets
    assert_html(html, "div[data-autocompleter--clade-target='wrap']" \
                       "[data-autocompleter--region-target='wrap']")

    # Search icon
    assert_html(html, "span.glyphicon.glyphicon-search")

    # Hidden field for term_id
    assert_html(html, "input[type='hidden'][name='filter[term_id]']" \
                       "[data-autocompleter--clade-target='hidden']" \
                       "[data-autocompleter--region-target='hidden']")

    # Text input with dual targets
    assert_html(html, "input[type='text'][name='filter[term]']" \
                       "[data-autocompleter--clade-target='input']" \
                       "[data-autocompleter--region-target='input']")

    # Dropdown with dual targets
    assert_html(html, "div.auto_complete.dropdown-menu" \
                       "[data-autocompleter--clade-target='pulldown']")
    assert_html(html, "ul.virtual_list" \
                       "[data-autocompleter--clade-target='list']")

    # 10 dropdown items
    assert_html(html, "li.dropdown-item", count: 10)

    # Type select with dual targets and swap actions
    assert_html(html, "select[name='filter[type]']" \
                       "[data-autocompleter--clade-target='select']")

    # Default clade selected
    assert_html(html, "option[value='clade'][selected]")
    assert_no_html(html, "option[value='region'][selected]")

    # Submit buttons
    assert_html(html, "input[type='submit'][value='#{:SEARCH.l}']")
    assert_html(html, "input[type='submit'][value='#{:CLEAR.l}']")
  end

  def test_renders_with_region_filter
    html = render_component(filter_type: "region",
                            filter_term: "North America")

    # Stimulus controller should be region
    assert_html(html, "form[data-controller='autocompleter--region']")
    assert_html(html, "form[data-type='region']")

    # Region should be selected
    assert_html(html, "option[value='region'][selected]")
    assert_no_html(html, "option[value='clade'][selected]")

    # Text field should have the filter term
    assert_html(html,
                "input[type='text'][name='filter[term]']" \
                "[value='North America']")
  end

  def test_renders_with_clade_filter
    html = render_component(filter_type: "clade",
                            filter_term: "Agaricales")

    assert_html(html, "form[data-controller='autocompleter--clade']")
    assert_html(html, "option[value='clade'][selected]")
    assert_html(html,
                "input[type='text'][name='filter[term]']" \
                "[value='Agaricales']")
  end

  def test_renders_empty_value_without_filter
    html = render_component

    assert_html(html,
                "input[type='text'][name='filter[term]'][value='']")
  end

  private

  def render_component(filter_type: nil, filter_term: nil)
    render(Components::IdentifyFilterForm.new(
             filter_type: filter_type,
             filter_term: filter_term
           ))
  end
end
