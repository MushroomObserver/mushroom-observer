# frozen_string_literal: true

#
#  = Search Test Helpers
#
#  Methods in this class are available to all the functional and integration
#  tests.
#
#  assert_search_redirected_to:: Assert a Searchable#create redirect to a
#                                 model's index.
#
################################################################################

module SearchExtensions
  # Searchable#create's redirect always carries always_index: 1 (see
  # ApplicationController::QueryParams#create_query_from_url_params) --
  # this folds that in so call sites only need to state the filters.
  def assert_search_redirected_to(controller:, params: {})
    assert_redirected_to(controller: controller, action: :index,
                         params: { always_index: 1, **params })
  end
end
