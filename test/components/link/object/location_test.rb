# frozen_string_literal: true

require("test_helper")

class LocationLinkTest < ComponentTestCase
  def test_renders_show_location_link_when_location_given
    burbank = locations(:burbank)
    html = render(Components::Link::Object::Location.new(
                    where: burbank.name, location: burbank
                  ))

    # Asserted attribute-by-attribute so the test pins behavior
    # (where it links, what selector class it carries) rather than
    # a particular compound-attribute order.
    assert_html(html, "a[href='#{routes.location_path(id: burbank.id)}']")
    assert_html(html, "a.show_location_link_#{burbank.id}")
    # Postal + scientific spans wrap the name so per-user formatting
    # CSS can hide whichever the user didn't pick.
    assert_html(html, "a span.location-postal", text: burbank.name)
    assert_html(html, "a span.location-scientific",
                text: Location.reverse_name(burbank.name))
  end

  def test_location_integer_id_is_looked_up
    burbank = locations(:burbank)
    html = render(Components::Link::Object::Location.new(
                    where: burbank.name, location: burbank.id
                  ))

    # Integer in the `location:` slot triggers a `Location.find` —
    # callers from older helpers passed bare ids.
    assert_html(html, "a.show_location_link_#{burbank.id}")
  end

  def test_count_suffix_appended
    burbank = locations(:burbank)
    html = render(Components::Link::Object::Location.new(
                    where: burbank.name, location: burbank, count: 7
                  ))

    # Locations index uses count to show "<name> (7)".
    assert_includes(html, "(7)")
  end

  def test_click_appends_map_suffix
    burbank = locations(:burbank)
    html = render(Components::Link::Object::Location.new(
                    where: burbank.name, location: burbank, click: true
                  ))

    assert_includes(html, :click_for_map.t)
  end

  def test_without_location_renders_observations_index_link
    where = "Some Place, USA"
    html = render(Components::Link::Object::Location.new(where: where))

    # Fallback: no resolved Location → link to observations index
    # filtered by `where=`, with a distinct selector class.
    assert_html(html, "a[href='#{routes.observations_path(where: where)}']")
    assert_html(html, "a.index_observations_at_where_link")
    assert_html(html, "a span.location-postal", text: where)
  end

  def test_click_on_where_link_appends_search_suffix
    html = render(Components::Link::Object::Location.new(
                    where: "Some Place, USA", click: true
                  ))

    assert_includes(html, :SEARCH.t)
  end
end
