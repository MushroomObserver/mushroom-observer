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
    name = names(:fungi)
    assert_equal("Fungi", mycobank_taxon(name))

    name = names(:agaricus)
    assert_equal("Agaricus", mycobank_taxon(name))

    name = names(:amanita_subgenus_lepidella)
    assert_equal("Amanita", mycobank_taxon(name),
                 "MycoBank taxon name for Ranks between Genus and Species" \
                 "should == genus")

    name = names(:coprinus_comatus)
    assert_equal("Coprinus%20comatus", mycobank_taxon(name))

    name = names(:amanita_boudieri_var_beillei)
    assert_equal("Amanita%20boudieri%20var.%20beillei", mycobank_taxon(name))
  end

  def test_link_if_object
    # link to project, name not supplied
    # pre  = '<a href="/project/show_project/'
    path = "/project/show_project/"
    obj = projects(:bolete_project)
    link_text = "Bolete Project"
    assert_equal(expected_link(path, obj, link_text),
                 link_to_object(projects(:bolete_project))
                )
    # link to project, name supplied
    link_text = "BP"
    assert_equal(expected_link(path, obj, link_text),
                 link_to_object(projects(:bolete_project), "BP")
                )
    # link to species list
    path = "/species_list/show_species_list/"
    obj = species_lists(:first_species_list)
    link_text = "A Species List"
    assert_equal(expected_link(path, obj, link_text),
                 link_to_object(species_lists(:first_species_list))
                )
    # link to non-existent object, name not supplied
    assert_nil(link_to_object(nil), "Non-existent object should lack link.")
    # link to non-existent object, name supplied
    assert_nil(link_to_object(nil, "Nada"),
               "Non-existent object should lack link.")
  end

  def expected_link(path, obj, link_text)
    '<a href="' + path + obj.id.to_s + '">' + link_text + "</a>"
  end
end
