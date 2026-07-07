# frozen_string_literal: true

require("test_helper")

# Tests for Name::PropagateGenericClassifications
# (app/models/name/propagate_generic_classifications.rb)
class Name::PropagateGenericClassificationsTest < UnitTestCase
  def test_can_propagate
    assert(names(:coprinus).can_propagate?,
           "Genus s.s. Classifications should be propagable")

    assert_false(names(:coprinus_sensu_lato).can_propagate?,
                 "Names sensu lato Classifications should not be propagable")

    [:eukarya, :fungi, :ascomycota, :ascomycetes, :agaricales, :agaricaceae,
     :amanita_subgenus_lepidella, :sect_agaricus, :coprinus_comatus,
     :amanita_boudieri_var_beillei, :boletus_edulis_group].
      each do |name|
        assert_false(
          names(name).can_propagate?,
          "#{names(name).rank} Classifications should not be propagable"
        )
      end
  end

  def test_propagate_generic_classifications
    # This should result in the classification of Coprinus being copied to
    # Chlorophyllum rachodes.
    c_rachodes = names(:chlorophyllum_rachodes)
    c_comatus = names(:coprinus_comatus)
    c_rachodes.merge_synonyms(c_comatus)
    c_rachodes.update(deprecated: true)
    c_comatus.update(deprecated: false)
    wrong_class = c_rachodes.classification.sub("Agaricaceae", "Boletaceae")
    c_rachodes.update(classification: wrong_class)
    c_rachodes.reload
    c_comatus.reload
    assert_not_empty(c_rachodes.observations)
    assert_not_equal(c_rachodes.classification, names(:coprinus).classification)

    # This should result in the species in Agaricus having their
    # classifications stripped.  (Presently, I'm deeming this safer than
    # trusting old classifications which cannot even be seen on the website
    # anymore. It should be impossible to set a species's classification
    # to be different from the genus deliberately these days.)
    a_campestris = names(:agaricus_campestris)
    observations(:agaricus_campestrus_obs).destroy
    observations(:agaricus_campestras_obs).destroy
    observations(:agaricus_campestros_obs).destroy
    names(:agaricus).update(classification: nil)
    assert_not_empty(a_campestris.observations)

    # It should fill these in from Lepiota.
    l_rachodes = names(:lepiota_rachodes)
    l_rhacodes = names(:lepiota_rhacodes)
    l_rachodes.update(classification: nil)
    l_rhacodes.update(classification: "")
    observations(:minimal_unknown_obs).update(
      name: l_rhacodes,
      text_name: l_rhacodes.text_name
    )
    assert_empty(l_rachodes.observations)
    assert_not_empty(l_rhacodes.observations)

    # Make sure observations.text_name mirror is fully populated!
    Observation.refresh_content_filter_caches

    msgs = Name.propagate_generic_classifications

    # Should be, in any order:
    #   Fixing classification for C... rachodes: Boletaceae => Agaricaceae
    #   Stripping classification from Agaricus campestris
    #   Filling in classification for Lepiota rhacodes
    #   Setting classifications for blah,blah,blah.
    #   Setting classifications for blah,blah,blah,blah.
    assert(
      msgs.include?("Fixing classification of Chlorophyllum rachodes: " \
                    "Boletaceae => Agaricaceae") &&
        msgs.include?("Filling in classification for Lepiota rhacodes") &&
        msgs.include?("Stripping classification from Agaricus campestris") &&
        msgs.exclude?("Filling in classification for Lepiota rachodes") &&
        msgs.exclude?("Stripping classification from Agaricus campestras"),
      "Messages wrong.  Got this:\n#{msgs.inspect}\n"
    )

    # Make sure reported changes were actually made...
    assert_equal(c_comatus.classification, c_rachodes.reload.classification)
    assert_nil(a_campestris.reload.classification)
    assert_nil(names(:agaricus_campestrus).classification)
    assert_equal(names(:lepiota).classification,
                 l_rachodes.reload.classification)
    assert_equal(names(:lepiota).classification,
                 l_rhacodes.reload.classification)
  end
end
