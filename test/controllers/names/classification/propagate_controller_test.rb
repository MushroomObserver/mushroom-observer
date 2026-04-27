# frozen_string_literal: true

require("test_helper")

module Names::Classification
  class PropagateControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    # Description-mirror assertions removed — classification only
    # lives on Name now (discussion #4163).
    def test_propagate_classification
      genus = names(:coprinus)
      child = names(:coprinus_comatus)
      val   = genus.classification
      assert_equal(val, child.classification)

      # Make sure bogus requests don't crash.
      login("rolf")
      put(:update, params: { id: 666 })
      put(:update, params: { id: child.id })
      put(:update, params: { id: names(:ascomycota).id })
      assert_equal(val, genus.reload.classification)
      assert_equal(val, child.reload.classification)

      # Make sure have to be logged in. (update_column should avoid callbacks)
      new_val = names(:peltigera).classification
      genus.update_columns(classification: new_val)
      logout
      put(:update, params: { id: genus.id })
      assert_equal(val, child.reload.classification)

      # Now finally do it right and make sure it makes correct changes.
      login("rolf")
      put(:update, params: { id: genus.id })
      assert_equal(new_val, child.reload.classification)
    end
  end
end
