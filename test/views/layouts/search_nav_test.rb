# frozen_string_literal: true

require("test_helper")

class Views::Layouts::SearchNavTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    viewer = @user
    controller.define_singleton_method(:current_user) { viewer }
    stub_session(search_type: "observations")
    stub_controller_name!("observations")
  end

  def stub_session(search_type:)
    session = { search_type: search_type }
    controller.define_singleton_method(:session) { session }
  end

  def stub_controller_name!(name)
    controller.define_singleton_method(:controller_name) { name }
  end

  # The navbar wrapper itself is the collapse target (`.collapse`,
  # starting closed -- no `Components::Collapsible::EXPANDED_CLASS`)
  # so its padding/border disappear along with its content, rather
  # than a nested div collapsing inside an always-visible navbar.
  def test_renders_as_the_collapse_target
    html = render(Views::Layouts::SearchNav.new)

    assert_html(html, "div#search_nav.collapse")
    assert_no_html(html,
                   "#search_nav.#{Components::Collapsible::EXPANDED_CLASS}")
  end

  # Regression for #4492: Stimulus Array values must be JSON-encoded,
  # not space-joined — see the fuller regression test at
  # test/controllers/observations_controller_index_test.rb.
  def test_stimulus_array_values_are_json
    html = render(Views::Layouts::SearchNav.new)
    node = Nokogiri::HTML5.fragment(html).at_css("#search_nav")

    assert_not_nil(node)
    help_types = JSON.parse(node["data-search-type-help-types-value"])
    form_types = JSON.parse(node["data-search-type-form-types-value"])
    assert_equal(%w[names observations locations], help_types)
    assert_equal(
      %w[names observations locations projects herbaria species_lists],
      form_types
    )
  end

  def test_renders_search_bar_for_non_identify_controller
    html = render(Views::Layouts::SearchNav.new)

    assert_html(html, "#search_bar_elements")
    assert_no_html(html, "form#identify_filter")
  end

  def test_renders_form_filter_for_identify_controller
    stub_controller_name!("identify")

    html = render(Views::Layouts::SearchNav.new)

    assert_html(html, "form#identify_filter")
    assert_no_html(html, "#search_bar_elements")
  end
end
