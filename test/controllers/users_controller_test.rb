# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Users
#  users_controller
# ------------------------------------------------------------
class UsersControllerTest < FunctionalTestCase
  def modified_generic_params(params, user)
    params[:username] = user.login
    params
  end

  def test_page_loads
    login
    get_with_dump(:show, params: { id: rolf.id })
    assert_template(:show)
  end

  # def test_some_admin_pages
  #   [
  #     [:users_by_name,  "list_users", {}],
  #   ].each do |page, response, params|
  #     logout
  #     get(page, params: params)
  #     assert_redirected_to(controller: :account, action: :login)

  #     login("rolf")
  #     get(page, params: params)
  #     assert_redirected_to(action: :index)
  #     assert_flash_text(/denied|only.*admin/i)

  #     make_admin("rolf")
  #     get_with_dump(page, params)
  #     assert_template(response) # 1
  #   end
  # end

  #   -------------
  #    user_search
  #   -------------

  # Prove that user-type pattern searches go to correct page
  # When pattern is a user's id, go directly to that user's page
  def test_user_search_id
    login
    user = users(:rolf)
    get(:index, params: { pattern: user.id })
    assert_redirected_to(user_path(user.id))
  end

  # When a non-id pattern matches only one user, show that user.
  def test_user_search_name
    login
    user = users(:uniquely_named_user)
    get(:index, params: { pattern: user.name })
    # Must test against regex because passed query param borks path match
    assert_redirected_to(/#{user_path(user.id)}/)
  end

  # When pattern matches multiple users, list them.
  def test_user_search_multiple_hits
    login
    pattern = "Roy"
    get(:index, params: { pattern: pattern })
    # matcher includes optional quotation mark (?.)
    assert_match(/Users Matching .?#{pattern}/, css_select("title").text,
                 "Wrong page displayed")

    prove_sorting_links_include_contribution
  end

  # When pattern has no matches, go to list page with flash message,
  #  title displayed is default no_hits_title
  def test_user_search_unmatched
    login
    unmatched_pattern = "NonexistentUserContent"
    get_without_clearing_flash(:index,
                               params: { pattern: unmatched_pattern })
    assert_template("users/index")

    assert_equal(
      :title_for_user_search.t,
      @controller.instance_variable_get(:@title),
      "metadata <title> tag incorrect"
    )
    assert_empty(css_select("#sorts"),
                 "There should be no sort links")

    flash_text = :runtime_no_matches.l.sub("[types]", "users")
    assert_flash_text(flash_text)
  end

  #   ---------------------
  #    show_selected_users
  #   ---------------------

  # Prove that sorting links include "Contribution" (when not in admin mode)
  def prove_sorting_links_include_contribution
    sorting_links = css_select("#sorts")
    assert_match(/Contribution/, sorting_links.text)
  end

  def test_show_next
    query = Query.lookup_and_save(:User, :all)
    assert_operator(query.num_results, :>, 1)
    number8 = query.results[7]
    number9 = query.results[8]
    q = query.record.id.alphabetize

    login
    get(:show, params: { id: number8.id, q: q, flow: "next" })
    assert_redirected_to(user_path(number9.id, q: q))
  end

  def test_show_prev
    query = Query.lookup_and_save(:User, :all)
    assert_operator(query.num_results, :>, 1)
    number8 = query.results[7]
    number7 = query.results[6]
    q = query.record.id.alphabetize

    login
    get(:show, params: { id: number8.id, q: q, flow: "prev" })
    assert_redirected_to(user_path(number7.id, q: q))
  end

  #   ---------------
  #    admin actions
  #   ---------------

  # Prove that user_index is restricted to admins
  def test_index
    login("rolf")
    get(:index)
    assert_redirected_to(:root)

    make_admin
    get(:index)
    assert_response(:success)
  end

  def test_change_bonuses
    user = users(:mary)
    old_contribution = mary.contribution
    bonus = "7 lucky \n 13 unlucky"

    # Prove that non-admin cannot change bonuses and attempt to do so
    # redirects to target user's page
    login("rolf")
    get(:edit, params: { id: user.id })
    assert_redirected_to(user_path(user.id))

    # Prove that admin posting bonuses in wrong format causes a flash error,
    # leaving bonuses and contributions unchanged.
    make_admin
    post(:update, params: { id: user.id, val: "wong format 7" })
    assert_flash_error
    user.reload
    assert_empty(user.bonuses)
    assert_equal(old_contribution, user.contribution)

    # Prove that admin can change bonuses
    post(:update, params: { id: user.id, val: bonus })
    user.reload
    assert_equal([[7, "lucky"], [13, "unlucky"]], user.bonuses)
    assert_equal(old_contribution + 20, user.contribution)

    # Prove that admin can get bonuses
    get(:edit, params: { id: user.id })
    assert_response(:success)
  end
end
