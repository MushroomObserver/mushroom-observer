require "test_helper"

class UserControllerTest < FunctionalTestCase

  # ------------------------------------------------------------
  #  User
  #  User_controller
  # ------------------------------------------------------------

  def test_show_user_no_id
    get_with_dump(:show_user)
    assert_redirected_to(action: :index_user)
  end

  def test_some_admin_pages
    [
      [:users_by_name,  "list_users", {}],
      [:email_features, "email_features", {}]
    ].each do |page, response, params|
      logout
      get(page, params: params)
      assert_redirected_to(controller: :account, action: :login)

      login("rolf")
      get(page, params: params)
      assert_redirected_to(controller: :rss_log, action: :list_rss_logs)
      assert_flash_text(/denied|only.*admin/i)

      make_admin("rolf")
      get_with_dump(page, params)
      assert_template(response) # 1
    end
  end

  #   -------------
  #    user_search
  #   -------------

  # Prove that user-type pattern searches go to correct page
  # When pattern is a user's id, go directly to that user's page
  def test_user_search_id
    user = users(:rolf)
    get(:user_search, params: { pattern: user.id })
    assert_redirected_to(action: "show_user", id: user.id)
  end

  # When a non-id pattern matches only one user, show that user.
  def test_user_search_name
    user = users(:uniquely_named_user)
    get(:user_search, params: { pattern: user.name })
    assert_redirected_to(%r{/show_user/#{user.id}})
  end

  # When pattern matches multiple users, list them.
  def test_user_search_multiple_hits
    pattern = "Roy"
    get(:user_search, params: { pattern: pattern })
    # matcher includes optional quotation mark (?.)
    assert_match(/Users Matching .?#{pattern}/, css_select("title").text,
                 "Wrong page displayed")

    prove_sorting_links_include_contribution
  end

  # When pattern has no matches, go to list page with flash message,
  #  title not displayed and default metadata title
  def test_user_search_unmatched
    unmatched_pattern = "NonexistentUserContent"
    get_without_clearing_flash(:user_search,
                               params: { pattern: unmatched_pattern })
    assert_template(:list_users)

    assert_empty(@controller.instance_variable_get("@title"),
                 "Displayed title should be empty")
    assert_equal(css_select("title").text, "Mushroom Observer: User Search",
                 "metadata <title> tag incorrect")
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

  def test_next_user_and_prev_user
    # users sorted in default order
    users_alpha = User.order(:name)

    get(:next_user, params: { id: users_alpha.fourth.id })
    assert_redirected_to(action: :show_user, id: users_alpha.fifth.id,
                         params: @controller.query_params(QueryRecord.last))

    get(:prev_user, params: { id: users_alpha.fourth.id })
    assert_redirected_to(action: :show_user, id: users_alpha.third.id,
                         params: @controller.query_params(QueryRecord.last))
  end

  #   ---------------
  #    admin actions
  #   ---------------

  # Prove that user_index is restricted to admins
  def test_index_user
    login("rolf")
    get(:index_user)
    assert_redirected_to(:root)

    make_admin
    get(:index_user)
    assert_response(:success)
  end

  def test_change_user_bonuses
    user = users(:mary)
    old_contribution = mary.contribution
    bonus = "7 lucky \n 13 unlucky"

    # Prove that non-admin cannot change bonuses and attempt to do so
    # redirects to target user's page
    login("rolf")
    get(:change_user_bonuses, params: { id: user.id })
    assert_redirected_to(action: :show_user, id: user.id)

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
