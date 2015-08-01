require "test_helper"

class ObjectLinkHelperTest < ActionView::TestCase
# help for links in views

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
    name = Name.find(1)   # Fungi
    assert_equal("Fungi", mycobank_taxon(name))

    name = Name.find(18)  # Agaricus
    assert_equal("Agaricus", mycobank_taxon(name))

    name = Name.find(52)  # Amanita subgenus Lepidella
    assert_equal("Amanita", mycobank_taxon(name),
      "MycoBank taxon name for Ranks between Genus and Species should == genus")

    name = Name.find(2)   # Coprinus comatus
    assert_equal("Coprinus%20comatus", mycobank_taxon(name))

    name = Name.find(53)  # Amanita boudieri var. beillei
    assert_equal("Amanita%20boudieri%20var.%20beillei", mycobank_taxon(name))
  end
end
