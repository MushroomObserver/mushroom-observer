# frozen_string_literal: true

require("test_helper")

# test helper for links in views
class ObjectLinkHelperTest < ActionView::TestCase
  def test_name_link
    name = names(:suillus)
    path = name_path(name.id)
    html_id = "show_name_link_#{name.id}"

    link_text = "#{:NAME.l} ##{name.id}"
    assert_equal(expected_link(path, html_id, link_text), name_link(name.id))

    link_text = name.display_name_brief_authors.t
    assert_equal(expected_link(path, html_id, link_text), name_link(name))
  end

  def test_link_if_object
    # link to project, name not supplied
    # pre  = '<a href="/projects/'
    proj = projects(:bolete_project)
    path = project_path(proj.id)
    html_id = "show_project_link_#{proj.id}"
    link_text = "Bolete Project"
    assert_equal(expected_link(path, html_id, link_text),
                 link_to_object(projects(:bolete_project)))
    # link to project, name supplied
    link_text = "BP"
    assert_equal(expected_link(path, html_id, link_text),
                 link_to_object(projects(:bolete_project), "BP"))
    # link to species list
    spl = species_lists(:first_species_list)
    path = species_list_path(spl.id)
    html_id = "show_species_list_link_#{spl.id}"
    link_text = "A Species List"
    assert_equal(expected_link(path, html_id, link_text),
                 link_to_object(species_lists(:first_species_list)))
    # link to non-existent object, name not supplied
    assert_nil(link_to_object(nil), "Non-existent object should lack link.")
    # link to non-existent object, name supplied
    assert_nil(link_to_object(nil, "Nada"),
               "Non-existent object should lack link.")
  end

  # - Helper Methods -----------------------------------------------------------

  def expected_link(path, html_id, link_text)
    "<a id=\"#{html_id}\" href=\"#{path}\">#{link_text}</a>"
  end
end
