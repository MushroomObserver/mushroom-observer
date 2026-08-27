# frozen_string_literal: true

require "test_helper"

class PatternSearchFormTest < ComponentTestCase
  def render_form(pattern: "", type: "observations")
    render(Components::Form::PatternSearch.new(
             FormObject::PatternSearch.new(pattern: pattern, type: type)
           ))
  end

  def test_dropdown_matches_pattern_searchable_models_minus_images
    html = render_form

    (SearchController::PATTERN_SEARCHABLE_MODELS - [:images]).each do |type|
      assert_html(html,
                  "select[name='pattern_search[type]'] " \
                  "option[value='#{type}']")
    end
  end

  def test_dropdown_excludes_images
    html = render_form

    assert_no_html(html,
                   "select[name='pattern_search[type]'] " \
                   "option[value='images']")
  end

  def test_dropdown_includes_google
    html = render_form

    assert_html(html,
                "select[name='pattern_search[type]'] option[value='google']")
  end
end
