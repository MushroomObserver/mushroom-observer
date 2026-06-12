# frozen_string_literal: true

require("test_helper")

# test helper for links in views
class ObjectLinkHelperTest < ActionView::TestCase
  def test_name_link
    name = names(:suillus)
    path = name_path(name.id)
    html_class = "name_link_#{name.id}"

    assert_link(name_link(name.id), path: path, html_class: html_class,
                                    link_text: "#{:NAME.l} ##{name.id}")
    assert_link(name_link(name), path: path, html_class: html_class,
                                 link_text: name.display_name_brief_authors.t)
  end

  def test_link_if_object
    proj = projects(:bolete_project)
    path = project_path(proj.id)
    html_class = "project_link_#{proj.id}"

    assert_link(link_to_object(proj),
                path: path, html_class: html_class,
                link_text: "Bolete Project")
    assert_link(link_to_object(proj, "BP"),
                path: path, html_class: html_class,
                link_text: "BP")

    spl = species_lists(:first_species_list)
    assert_link(link_to_object(spl),
                path: species_list_path(spl.id),
                html_class: "species_list_link_#{spl.id}",
                link_text: "An Observation List")
    # link to non-existent object, name not supplied
    assert_nil(link_to_object(nil), "Non-existent object should lack link.")
    # link to non-existent object, name supplied
    assert_nil(link_to_object(nil, "Nada"),
               "Non-existent object should lack link.")
  end

  def test_user_link_with_nil
    result = user_link(nil)
    assert_equal(:unknown_user_name.l, result)
  end

  def test_user_link_with_user
    user = users(:rolf)

    assert_link(user_link(user),
                path: user_path(user.id),
                html_class: "user_link_#{user.id}",
                link_text: user.unique_text_name)
  end

  def test_user_link_with_integer_id
    user = users(:rolf)
    result = user_link(user.id)
    path = user_path(user.id)

    assert_includes(result, "href=\"#{path}\"")
    assert_includes(result, "#{:USER.l} ##{user.id}")
    assert_includes(result, "user_link_#{user.id}")
  end

  def test_where_string_postal_and_scientific_spans
    result = where_string("Berkeley, California, USA")

    assert_includes(result, "location-postal")
    assert_includes(result, "location-scientific")
    assert_includes(result, "Berkeley, California, USA")
    # Scientific reverses the postal order.
    assert_includes(result, Location.reverse_name("Berkeley, California, USA"))
  end

  def test_where_string_appends_count
    result = where_string("Berkeley, California, USA", 7)

    assert_includes(result, "(7)")
  end

  def test_location_link_with_location_object
    location = locations(:burbank)
    result = location_link(location.name, location)

    assert_includes(result, "href=\"#{location_path(id: location.id)}\"")
    assert_includes(result, "show_location_link_#{location.id}")
  end

  def test_location_link_with_location_id_lookup
    location = locations(:burbank)
    # Pass the id (Integer) — method does Location.find(location).
    result = location_link(location.name, location.id)

    assert_includes(result, "href=\"#{location_path(id: location.id)}\"")
  end

  def test_location_link_click_to_map_suffix
    location = locations(:burbank)
    result = location_link(location.name, location, nil, true)

    assert_includes(result, :click_for_map.t)
  end

  def test_location_link_without_location_goes_to_search
    where = "Some Place, USA"
    result = location_link(where, nil)

    assert_includes(result, "index_observations_at_where_link")
    assert_includes(result, "href=\"#{observations_path(where: where)}\"")
  end

  def test_location_link_without_location_click_appends_search_suffix
    result = location_link("Some Place, USA", nil, nil, true)

    assert_includes(result, :SEARCH.t)
  end

  def test_observation_herbarium_record_link_zero_with_specimen
    obs = observations(:minimal_unknown_obs)
    obs.herbarium_records.destroy_all
    obs.update(specimen: true)

    assert_equal(:show_observation_specimen_available.t,
                 observation_herbarium_record_link(obs))
  end

  def test_observation_herbarium_record_link_zero_without_specimen
    obs = observations(:minimal_unknown_obs)
    obs.herbarium_records.destroy_all
    obs.update(specimen: false)

    assert_equal(:show_observation_specimen_not_available.t,
                 observation_herbarium_record_link(obs))
  end

  def test_observation_herbarium_record_link_with_records
    obs = observations(:detailed_unknown_obs)
    result = observation_herbarium_record_link(obs)

    assert_includes(result, "herbarium_records_for_observation_link")
    assert_includes(result,
                    "href=\"#{herbarium_records_path(observation: obs.id)}\"")
  end

  # - Helper Methods -----------------------------------------------------------

  # Parses the rendered `<a>` and asserts href / class / text
  # independently. Order-insensitive on attributes — the different
  # link helpers emit attributes in different orders (Rails
  # `link_to` emits class first; the Phlex `Components::*Link`
  # variants emit href first).
  def assert_link(rendered, path:, html_class:, link_text:)
    link = Nokogiri::HTML.fragment(rendered).at("a")

    assert_not_nil(link, "Expected an <a> in:\n#{rendered}")
    assert_equal(path, link["href"])
    assert_equal(html_class, link["class"])
    assert_equal(link_text, link.inner_html)
  end
end
