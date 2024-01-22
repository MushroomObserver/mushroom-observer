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
    get(:show, params: { id: rolf.id })
    assert_template(:show)
  end

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

    assert_match(
      :title_for_user_search.t,
      css_select("title").text,
      "metadata <title> tag incorrect"
    )
    assert_empty(css_select("#sorts"),
                 "There should be no sort links")

    flash_text = :runtime_no_matches.l.sub("[types]", "users")
    assert_flash_text(flash_text)
  end

  #   ---------------
  #    show
  #   ---------------

  def test_show
    user = users(:rolf)

    login
    get(:show, params: { id: user.id })

    assert_template(:show)
    # assert_select(
    #   "a[href = '#{location_descriptions_path}?by_author=#{user.id}']"
    # )
    # assert_select(
    #   "a[href = '#{name_descriptions_path}?by_author=#{user.id}']"
    # )
    # assert_select(
    #   "a:match('href', ?)",
    #   /\?.*=(\d+).*&id=\1/, # some param=n followed by id with same value
    #   false,
    #   "Links should not use the same value for id and another param"
    # )
    # assert_select(
    #   "a:match('href', ?)",
    #   /\?.*id=(\d+).*&\S+=\1/, # id=n followed by another param with same value
    #   false,
    #   "Links should not use the same value for id and another param"
    # )
  end

  #   ---------------
  #    admin actions
  #   ---------------

  # Prove that user_index (without search or id param) is restricted to admins
  def test_index
    login("rolf")
    get(:index)
    assert_redirected_to(:root)

    make_admin
    get(:index)
    assert_response(:success)
  end

  def test_index_sorted_by_last_login
    by = "last_login"

    login
    make_admin
    get(:index, params: { by: by })

    assert_displayed_title("Users by Last Login")
  end

  def test_index_sorted_by_contribution
    by = "contribution"

    login
    make_admin
    get(:index, params: { by: by })

    assert_displayed_title("Users by Contribution")
  end

  #   ---------------------
  #    show_selected_users
  #   ---------------------

  # The unfiltered user :index is admin-only, but selected/searched users
  # can be shown via the same action.
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
end
