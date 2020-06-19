# frozen_string_literal: true

require "test_helper"

# test helper for links in views
class ObjectLinkHelperTest < ActionView::TestCase
  def test_mycobank_language_suffix
    # language exists in MO and in Mycobank translation
    assert_equal("&Lang=Fra", mycobank_language_suffix(:fr))

    # does not exist in MO and exists in Mycobank translation
    assert_equal("&Lang=Ara", mycobank_language_suffix(:ar))

    # exists in MO but not in Mycobank translation
    assert_equal("&Lang=Eng", mycobank_language_suffix(:ru))

    # does not (yet) exist in MO and does not exist in Mycobank translation
    assert_equal("&Lang=Eng", mycobank_language_suffix(:mycologish))

    # MO and Mycobank defaults (but not in Mycobank "translation")
    assert_equal("&Lang=Eng", mycobank_language_suffix(:en))
  end

  def test_mycobank_taxon
    # Happy path (text_name)
    name = names(:coprinus_comatus)
    assert_equal(name.text_name, mycobank_taxon(name))

    # Also happy path; test to make sure not accidentally chopping var.
    name = names(:amanita_boudieri_var_beillei)
    assert_equal(name.text_name, mycobank_taxon(name))

    name = names(:amanita_subgenus_lepidella)
    assert_equal("Amanita", mycobank_taxon(name),
                 "MycoBank taxon name for Ranks between Genus and Species" \
                 " should end before rank")

    name = names(:boletus_edulis_group)
    assert_equal("Boletus edulis", mycobank_taxon(name),
                 "MycoBank taxon for group should include binomial")
  end

  def test_link_if_object
    # link to project, name not supplied
    # pre  = '<a href="/projects/show_project/'
    path = "/projects/"
    obj = projects(:bolete_project)
    link_text = "Bolete Project"
    assert_equal(expected_link(path, obj, link_text),
                 link_to_object(projects(:bolete_project)))
    # link to project, name supplied
    link_text = "BP"
    assert_equal(expected_link(path, obj, link_text),
                 link_to_object(projects(:bolete_project), "BP"))
    # link to species list
    path = "/species_lists/"
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
    '<a href="' + path + obj.id.to_s + '">' + link_text + "</a>"
  end

  def test_object_path
    obj = projects(:bolete_project)
    assert_equal(project_path(obj.id), object_path(obj))
    assert_equal(project_path(obj.id, q: 12_345), object_path(obj, q: 12_345))

    obj = collection_numbers(:coprinus_comatus_coll_num)
    assert_equal(collection_number_path(obj.id), object_path(obj))
    assert_equal(collection_number_path(obj.id, q: 12_345),
                 object_path(obj, q: 12_345))
  end
end
