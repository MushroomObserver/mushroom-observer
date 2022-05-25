# frozen_string_literal: true

require("test_helper")

class SynonymTest < UnitTestCase
  def test_make_sure_all_referenced_synonyms_exist
    # Make sure there is at least one unused synonym.
    unused_id = Synonym.create.id
    assert_not_nil(Synonym.safe_find(unused_id))

    # Make sure there is at least one missing synonym.
    missing_id = names(:macrolepiota_rachodes).synonym_id
    Synonym.where(id: missing_id).delete_all
    assert_nil(Synonym.safe_find(missing_id))

    # Run cronjob to fix these sorts of things and make sure it fixes them.
    msgs = Synonym.make_sure_all_referenced_synonyms_exist
    assert_nil(Synonym.safe_find(unused_id))
    assert_not_nil(Synonym.safe_find(missing_id))
    assert_includes(msgs.join(""), unused_id.to_s)
    assert_includes(msgs.join(""), missing_id.to_s)
  end
end
