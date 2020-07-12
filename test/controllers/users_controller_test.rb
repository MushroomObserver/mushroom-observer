# frozen_string_literal: true

require "test_helper"

# Test user controller
# extracted from master ObserverControllerTest
class UsersControllerTest < FunctionalTestCase

  # ------------------------------------------------------------
  # indexes / searches
  # ------------------------------------------------------------

  # Prove that user_index is restricted to admins
  def test_index_user
    login("rolf")
    get(:index_user)
    assert_redirected_to(:root)

    make_admin
    get(:index_user)
    assert_response(:success)
  end

  # Prove that user-type pattern searches go to correct page
  # When pattern is a user's id, go directly to that user's page
  def test_user_search_id
    user = users(:rolf)
    get(:user_search, params: { pattern: user.id })
    assert_redirected_to(action: :show, id: user.id)
  end

  # When a non-id pattern matches only one user, show that user.
  def test_user_search_name
    user = users(:uniquely_named_user)
    get(:user_search, params: { pattern: user.name })
    assert_redirected_to(/#{user_path(user.id)}/)
  end

  # When pattern matches multiple users, list them.
  def test_user_search_multiple_hits
    pattern = "Roy"
    get(:user_search, params: { pattern: pattern })
    # matcher includes optional quotation mark (?.)
    assert_match(/Users Matching .?#{pattern}/, css_select("title").text,
                 "Wrong page displayed")
    assert_select("#sorts", { text: /Contribution/ },
                  "Page is missing a link to sort Users by Contribution" )
  end

  # When pattern has no matches, go to list page with flash message,
  #  title not displayed and default metadata title
  def test_user_search_unmatched
    unmatched_pattern = "NonexistentUserContent"
    get_without_clearing_flash(:user_search,
                               params: { pattern: unmatched_pattern })
    assert_template(:index)
    assert_empty(@controller.instance_variable_get("@title"),
                 "Displayed title should be empty")
    assert_select("head title", { text: "Mushroom Observer: User Search" },
                  "metadata <title> tag incorrect")
    assert_select("#sorts", false, "There should be no sort links")

    flash_text = :runtime_no_matches.l.sub("[types]", "users")
    assert_flash_text(flash_text)
  end

  #   ---------------------
  #    show
  #   ---------------------

  def test_show_no_id
    assert_raises(ActionController::UrlGenerationError) do
      get(:user)
    end
    # assert_redirected_to(users_index_user_path)
    assert_empty(@response.body)
  end

  def test_show_next_and_prev
    # users sorted in default order
    users_alpha = User.order(:name)

    get(:show_next, params: { id: users_alpha.fourth.id })
    assert_redirected_to(action: :show, id: users_alpha.fifth.id,
                         params: @controller.query_params(QueryRecord.last))

    get(:show_prev, params: { id: users_alpha.fourth.id })
    assert_redirected_to(action: :show, id: users_alpha.third.id,
                         params: @controller.query_params(QueryRecord.last))
  end

  #   -----------
  #    checklist
  #   -----------

  # Prove that Life List goes to correct page which has correct content
  def test_checklist_for_user
    user = users(:rolf)
    expect = Name.joins(observations: :user).
             where("observations.user_id = #{user.id}
                    AND names.rank = #{Name.ranks[:Species]}").distinct

    get(:checklist, params: { id: user.id })
    assert_match(/Checklist for #{user.name}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Species List checklist goes to correct page with correct content
  def test_checklist_for_species_list
    list = species_lists(:one_genus_three_species_list)
    expect = Name.joins(observations: :observations_species_lists).
             where("observations_species_lists.species_list_id
                        = #{list.id}
                    AND names.rank = #{Name.ranks[:Species]}").distinct

    get(:checklist, params: { species_list_id: list.id })
    assert_match(/Checklist for #{list.title}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Project checklist goes to correct page with correct content
  def test_checklist_for_project
    project = projects(:one_genus_two_species_project)
    expect = Name.joins(observations: :observations_projects).
             where("observations_projects.project_id = #{project.id}
                    AND names.rank = #{Name.ranks[:Species]}").distinct

    get(:checklist, params: { project_id: project.id })
    assert_match(/Checklist for #{project.title}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Site checklist goes to correct page with correct content
  def test_checklist_for_site
    expect = Name.joins(:observations).
             where(rank: Name.ranks[:Species]).distinct

    get(:checklist)
    assert_match(/Checklist for #{:app_title.l}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  def prove_checklist_content(expect)
    # Get expected names not included in the displayed checklist links.
    missing_names = (
      expect.each_with_object([]) do |taxon, missing|
        next if /#{taxon.text_name}/.match?(css_select(".checklist a").text)

        missing << taxon.text_name
      end
    )

    assert_select(".checklist a", count: expect.size)
    assert(missing_names.empty?, "Species List missing #{missing_names}")
  end

  #   ---------------
  #    admin actions
  #   ---------------

  def test_users_by_name
      logout
      get(:users_by_name)
      assert_redirected_to(controller: :account, action: :login)

      login("rolf")
      get(:users_by_name)
      assert_redirected_to(:root)
      assert_flash_text(/denied|only.*admin/i)

      make_admin("rolf")
      get(:users_by_name)
      assert_template("users/index")
  end

  def test_change_user_bonuses
    user = users(:mary)
    old_contribution = mary.contribution
    bonus = "7 lucky \n 13 unlucky"

    # Prove that non-admin cannot change bonuses and attempt to do so
    # redirects to target user's page
    login("rolf")
    get(:change_user_bonuses, params: { id: user.id })
    assert_redirected_to(action: :show, id: user.id)

    # Prove that admin posting bonuses in wrong format causes a flash error,
    # leaving bonuses and contributions unchanged.
    make_admin
    post(:change_user_bonuses, params: { id: user.id, val: "wong format 7" })
    assert_flash_error
    user.reload
    assert_empty(user.bonuses)
    assert_equal(old_contribution, user.contribution)

    # Prove that admin can change bonuses
    post(:change_user_bonuses, params: { id: user.id, val: bonus })
    user.reload
    assert_equal([[7, "lucky"], [13, "unlucky"]], user.bonuses)
    assert_equal(old_contribution + 20, user.contribution)

    # Prove that admin can get bonuses
    get(:change_user_bonuses, params: { id: user.id })
    assert_response(:success)
  end
end
