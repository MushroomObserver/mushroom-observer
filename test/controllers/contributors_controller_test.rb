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

  # This controller shares Query::Users with UsersController (see
  # `controller_model_name`), so every param Query::Users recognizes
  # -- not just `:by`/`:q`/`:id` -- is a live top-level filter here
  # too, through the generic dispatch in
  # ApplicationController::Indexes#build_index_with_query. Confirms
  # that's harmless: a recognized filter still renders the page, and
  # a bad record-backed id degrades to a redirect, not a crash.
  def test_index_recognizes_users_query_filter_param
    login
    get(:index, params: { has_contribution: "true" })

    assert_response(:success)
  end

  def test_index_bad_id_in_set_redirects_instead_of_crashing
    login
    get(:index, params: { id_in_set: [999_999_999] })

    assert_redirected_to(contributors_path)
  end
end
