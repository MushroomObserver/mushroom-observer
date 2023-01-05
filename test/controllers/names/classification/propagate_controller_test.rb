# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Classification
  class PropagateControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_propagate_classification
      genus = names(:coprinus)
      child = names(:coprinus_comatus)
      val   = genus.classification
      assert_equal(val, child.classification)
      assert_equal(val, child.description.classification)

      # Make sure bogus requests don't crash.
      login("rolf")
      get(:propagate_classification)
      get(:propagate_classification, params: { id: 666 })
      get(:propagate_classification, params: { id: "bogus" })
      get(:propagate_classification, params: { id: child.id })
      get(:propagate_classification, params: { id: names(:ascomycota).id })
      assert_equal(val, genus.reload.classification)
      assert_equal(val, genus.description.reload.classification)
      assert_equal(val, child.reload.classification)
      assert_equal(val, child.description.reload.classification)

      # Make sure have to be logged in. (update_column should avoid callbacks)
      new_val = names(:peltigera).classification
      genus.update_columns(classification: new_val)
      logout
      get(:propagate_classification, params: { id: genus.id })
      assert_equal(val, child.reload.classification)

      # Now finally do it right and make sure it makes correct changes.
      login("rolf")
      get(:propagate_classification, params: { id: genus.id })
      assert_equal(new_val, child.reload.classification)
      assert_equal(new_val, child.description.reload.classification)
    end
  end
end
