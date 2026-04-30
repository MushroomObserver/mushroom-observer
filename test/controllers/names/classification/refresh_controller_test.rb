# frozen_string_literal: true

require("test_helper")

module Names::Classification
  class RefreshControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    # Description-mirror assertions removed — classification only
    # lives on Name now (discussion #4163).
    def test_refresh_classification
      genus = names(:coprinus)
      child = names(:coprinus_comatus)
      val   = genus.classification
      time  = genus.updated_at
      assert_equal(val, child.classification)
      assert_equal(time, child.updated_at)

      # Make sure bogus requests don't crash.
      login("rolf")
      put(:update, params: { id: 666 })
      put(:update, params: { id: genus.id })
      put(:update, params: { id: child.id }) # no change!
      assert_equal(val, genus.reload.classification)
      assert_equal(val, child.reload.classification)
      assert_equal(time, genus.updated_at)
      assert_equal(time, child.updated_at)

      # Make sure have to be logged in. (update_column should avoid callbacks)
      new_val = names(:peltigera).classification
      child.update_columns(classification: new_val)
      logout
      put(:update, params: { id: child.id })
      assert_equal(new_val, child.reload.classification)
      assert_equal(time, child.updated_at)

      # Now finally do it right and make sure it makes correct changes.
      login("rolf")
      put(:update, params: { id: child.id })
      assert_equal(val, child.reload.classification)
      assert_not_equal(time, child.updated_at)
    end
  end
end
