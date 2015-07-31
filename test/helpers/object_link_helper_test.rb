require "test_helper"

class ObjectLinkHelperTest < ActionView::TestCase
# help for links in views

  def test_mycobank_language
    # language exists in MO and in Mycobank translation
    assert_equal("&Lang=Fra", mycobank_language_suffix(:fr))

    # does not exist in MO and exists in Mycobank translation
    assert_equal("&Lang=Ara", mycobank_language_suffix(:ar))

    # exists in MO but not in Mycobank translation
    assert_nil(mycobank_language_suffix(:ru))

    # does not exist in MO and does not exist in Mycobank translation
    assert_nil(mycobank_language_suffix(:mycologish))

    #  exists in MO and Mycobank but not in Mycobank "translation"
    assert_nil(mycobank_language_suffix(:en))
  end

  def test_mycobank_taxon
    name = Name.find(2)
    assert_equal(mycobank_taxon(name), "Coprinus%20comatus")
  end
end
