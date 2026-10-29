# frozen_string_literal: true

require("test_helper")

class Views::Layouts::SearchNavTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    viewer = @user
    controller.define_singleton_method(:current_user) { viewer }
    stub_session
  end

  def stub_session
    session = { search_type: "observations" }
    controller.define_singleton_method(:session) { session }
  end

  def test_renders_search_bar_for_non_identify_controller
    html = render(Views::Layouts::SearchNav.new)

    assert_html(html, "div#search_nav.collapse")
    assert_no_html(html, "#search_nav.in")
    assert_html(html, "form#pattern_search_form")
    assert_no_html(html, "form#identify_filter")
  end

  def test_renders_identify_form_filter_on_identify_pages
    controller.define_singleton_method(:controller_name) { "identify" }

    html = render(Views::Layouts::SearchNav.new)

    assert_html(html, "form#identify_filter")
    assert_no_html(html, "form#pattern_search_form")
  end

  # Regression guard for #4492: Stimulus Array values must be JSON,
  # not Phlex's space-joined default. See
  # `ObservationsControllerIndexTest` for the same guard at the
  # full-page level.
  def test_stimulus_array_values_are_json
    html = render(Views::Layouts::SearchNav.new)

    node = Nokogiri::HTML5.fragment(html).at_css("#search_nav")
    assert_not_nil(node, "search nav not rendered")
    %w[data-search-type-form-types-value
       data-search-type-help-types-value].each do |attr|
      parsed = JSON.parse(node[attr])
      assert_kind_of(Array, parsed, "#{attr} must be a JSON array")
      assert_includes(parsed, "observations", "#{attr} must list observations")
    end
  end
end
