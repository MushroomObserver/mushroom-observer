# frozen_string_literal: true

require("test_helper")

# test helper for links in views
class ObjectLinkHelperTest < ActionView::TestCase
  def test_link_if_object
    # link to project, name not supplied
    # pre  = '<a href="/project/show_project/'
    path = "/project/show_project/"
    obj = projects(:bolete_project)
    link_text = "Bolete Project"
    assert_equal(expected_link(path, obj, link_text),
                 link_to_object(projects(:bolete_project)))
    # link to project, name supplied
    link_text = "BP"
    assert_equal(expected_link(path, obj, link_text),
                 link_to_object(projects(:bolete_project), "BP"))
    # link to species list
    path = "/species_list/show_species_list/"
    obj = species_lists(:first_species_list)
    link_text = "A Species List"
    assert_equal(expected_link(path, obj, link_text),
                 link_to_object(species_lists(:first_species_list)))
    # link to non-existent object, name not supplied
    assert_nil(link_to_object(nil), "Non-existent object should lack link.")
    # link to non-existent object, name supplied
    assert_nil(link_to_object(nil, "Nada"),
               "Non-existent object should lack link.")
  end

  def expected_link(path, obj, link_text)
    #'<a href="' + path + obj.id.to_s + '">' + link_text + "</a>"
    "<a href=\"#{path}#{obj.id.to_s}\">#{link_text}</a>"
  end
end
