# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Contributors
#  contributors_controller
# ------------------------------------------------------------
class ContributorsControllerTest < FunctionalTestCase
  def test_page_load
    login
    get(:index)
  end

  def test_indexing_by_id
    login
    get(:index, params: { id: users(:rolf).id })
  end

  def test_index_with_non_default_sort
    check_index_sorting
  end
end
