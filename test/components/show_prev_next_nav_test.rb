# frozen_string_literal: true

require("test_helper")

class ShowPrevNextNavTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @user = users(:rolf)
    # Create a query with a controlled set of observations
    # Use by: :id to get predictable ordering
    @query = Query.lookup(:Observation, by: :id)
    @result_ids = @query.result_ids

    # Get observations at specific positions
    @first_obs = Observation.find(@result_ids.first)
    @last_obs = Observation.find(@result_ids.last)
    # Get a middle observation (at position 2)
    @middle_obs = Observation.find(@result_ids[2])
  end

  def test_renders_nothing_when_no_object
    html = render(Components::ShowPrevNextNav.new(
                    object: nil,
                    query: @query
                  ))

    assert_equal("", html)
  end

  def test_renders_nothing_when_no_query
    html = render(Components::ShowPrevNextNav.new(
                    object: @middle_obs,
                    query: nil
                  ))

    assert_equal("", html)
  end

  def test_renders_basic_structure
    @query.current_id = @middle_obs.id

    html = render(Components::ShowPrevNextNav.new(
                    object: @middle_obs,
                    query: @query
                  ))

    # Main container
    assert_includes(html, 'class="nav navbar-flex object_pager"')

    # Three li elements
    assert_html(html, "ul.object_pager > li", count: 3)

    # Prev, index, and next links
    assert_includes(html, "prev_object_link")
    assert_includes(html, "index_object_link")
    assert_includes(html, "next_object_link")
  end

  def test_prev_link_disabled_when_first_item
    @query.current_id = @first_obs.id

    html = render(Components::ShowPrevNextNav.new(
                    object: @first_obs,
                    query: @query
                  ))

    # Prev link should have disabled class
    assert_html(html, "a.prev_object_link.disabled")

    # Next link should NOT have disabled class
    doc = Nokogiri::HTML(html)
    next_link = doc.at_css("a.next_object_link")
    assert(next_link, "Expected next link")
    assert_not_includes(next_link["class"], "disabled")
  end

  def test_next_link_disabled_when_last_item
    @query.current_id = @last_obs.id

    html = render(Components::ShowPrevNextNav.new(
                    object: @last_obs,
                    query: @query
                  ))

    # Next link should have disabled class
    assert_html(html, "a.next_object_link.disabled")

    # Prev link should NOT have disabled class
    doc = Nokogiri::HTML(html)
    prev_link = doc.at_css("a.prev_object_link")
    assert(prev_link, "Expected prev link")
    assert_not_includes(prev_link["class"], "disabled")
  end

  def test_both_links_enabled_when_middle_item
    @query.current_id = @middle_obs.id

    html = render(Components::ShowPrevNextNav.new(
                    object: @middle_obs,
                    query: @query
                  ))

    doc = Nokogiri::HTML(html)

    prev_link = doc.at_css("a.prev_object_link")
    assert(prev_link, "Expected prev link")
    assert_not_includes(prev_link["class"], "disabled")

    next_link = doc.at_css("a.next_object_link")
    assert(next_link, "Expected next link")
    assert_not_includes(next_link["class"], "disabled")
  end

  def test_prev_link_has_correct_href
    @query.current_id = @middle_obs.id

    html = render(Components::ShowPrevNextNav.new(
                    object: @middle_obs,
                    query: @query
                  ))

    # Get the prev_id from the query
    expected_href = "/observations/#{@query.prev_id}"
    assert_html(html, "a.prev_object_link", attribute: { href: expected_href })
  end

  def test_next_link_has_correct_href
    @query.current_id = @middle_obs.id

    html = render(Components::ShowPrevNextNav.new(
                    object: @middle_obs,
                    query: @query
                  ))

    # Get the next_id from the query
    expected_href = "/observations/#{@query.next_id}"
    assert_html(html, "a.next_object_link", attribute: { href: expected_href })
  end

  def test_index_link_uses_grid_icon_for_observations
    @query.current_id = @middle_obs.id

    html = render(Components::ShowPrevNextNav.new(
                    object: @middle_obs,
                    query: @query
                  ))

    # Grid icon for observations
    assert_nested(
      html,
      parent_selector: "a.index_object_link",
      child_selector: "span.glyphicon-th"
    )
  end

  def test_index_link_uses_list_icon_for_names
    name_query = Query.lookup(:Name, by: :id)
    name_ids = name_query.result_ids
    middle_name = Name.find(name_ids[1])
    name_query.current_id = middle_name.id

    html = render(Components::ShowPrevNextNav.new(
                    object: middle_name,
                    query: name_query
                  ))

    # List icon for non-observations
    assert_nested(
      html,
      parent_selector: "a.index_object_link",
      child_selector: "span.glyphicon-list"
    )
  end

  def test_links_have_tooltips
    @query.current_id = @middle_obs.id

    html = render(Components::ShowPrevNextNav.new(
                    object: @middle_obs,
                    query: @query
                  ))

    # All links should have tooltip data attributes
    assert_includes(html, 'data-toggle="tooltip"')
  end

  def test_link_nesting_structure
    @query.current_id = @middle_obs.id

    html = render(Components::ShowPrevNextNav.new(
                    object: @middle_obs,
                    query: @query
                  ))

    # Links should be nested in li elements
    assert_nested(
      html,
      parent_selector: "ul.object_pager",
      child_selector: "li"
    )

    # Icon should be nested in link
    assert_nested(
      html,
      parent_selector: "a.prev_object_link",
      child_selector: "span.glyphicon"
    )

    # SR-only text should be in link
    assert_nested(
      html,
      parent_selector: "a.prev_object_link",
      child_selector: "span.sr-only"
    )
  end
end
