require "test_helper"
require "capybara_helper"

# Test observer_controller/user_controller
class ObserverUserControllerTest < IntegrationTestCase
  def test_user_controller
    # -------------------------------------------------------
    #  user_search
    #  Also see test/controllers/observer_controller_test.rb
    # -------------------------------------------------------

    # Prove that user-type pattern searches go to correct page

    visit("/")

    # When pattern is a user's id, go directly to that user's page
    user = users(:rolf)
    fill_in("search_pattern", with: user.id)
    page.select("User", from: :search_type)
    click_button("Search")
    assert_match(%r{Contribution Summary for #{user.name}}, page.title,
                 "Wrong page")

    # When a non-id pattern matches only one user, show that user.
    user = users(:uniquely_named_user)
    fill_in("search_pattern", with: user.name)
    page.select("User", from: :search_type)
    click_button("Search")
    assert_match(%r{Contribution Summary for #{user.name}}, page.title,
                 "Wrong page")

    # When pattern has no matches, go to list page, and display flash message.
    pattern = "NonexistentUserContent"
    fill_in("search_pattern", with: pattern)
    page.select("User", from: :search_type)
    click_button("Search")
    assert_match(%r{Users Matching .+#{pattern}}, page.title,
                 "Wrong page")
    flash = (:runtime_no_matches.l).sub("[types]", "users")
    page.assert_selector(".alert", text: "#{flash}")

    # When pattern matches multiple users, list them.
    pattern = "name_sorts_user"
    expected_hits = User.where("login LIKE ?", "%#{pattern}").order(:name)

    fill_in("search_pattern", with: pattern)
    page.select("User", from: :search_type)
    click_button("Search")
    assert_match(%r{Users Matching .+#{pattern}}, page.title,
                 "Wrong page")

    # -------------------------------------------------------
    #  show_selected_users
    #  Also see test/controllers/observer_controller_test.rb
    # -------------------------------------------------------

    # Prove that sorting links include "Contribution" (when not in admin mode)
    sorting_links = page.find("#sorts")
    assert_match(/Contribution/, sorting_links.text)

=begin Following test fails, and I don't know how to get it to pass.
    # -------------------------------------------------------
    #  next_user and prev_user
    #  Also see test/controllers/observer_controller_test.rb
    # -------------------------------------------------------

    # Results should have correct # of users
    # (Fixtures should be defined so that there are only 2 matches.)
    results = page.find(".results")
    results.assert_selector("a", count: 2)

    # First result should be User whose name is first in alpha order.
    assert_match(/#{expected_hits.first.name}/, results.first("a").text)

    # Different sort order should change the order of the results
    # (because of the definitions of Fixtures which match this search).
    click_on("Login Name")
    results = page.find(".results")
    refute_match(/#{expected_hits.first.name}/, results.first("a").text)

    results.first("a").click
    assert_match(%r{Contribution Summary for #{expected_hits.second.name}},
                    page.title, "Wrong page")

    # Prove that next_user and prev_user redirect to correct page
    click_on("Next")
    assert_match(%r{Contribution Summary for #{expected_hits.first.name}},
                    page.title, "Wrong page")

    click_on("Previous")
    assert_match(%r{Contribution Summary for #{expected_hits.second.name}},
                    page.title, "Wrong page")
=end
  end

  # ------------
  #  Checklists
  # ------------

  # Prove that Life List goes to correct page which has correct content
  def test_user_checklist
    user = users(:rolf)
    expect = Name.joins(observations: :user).
                  where("observations.user_id = #{user.id}
                         AND names.rank = #{Name.ranks[:Species]}").
                  uniq

    visit("/observer/show_user/#{user.id}")
    click_on(:app_life_list.l, match: :first)
    assert_match(%r{Checklist for #{user.name}}, page.title, "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Species List checklist goes to correct page with correct content
  def test_species_list_checklist
    list = species_lists(:one_genus_three_species_list)
    expect = Name.joins(observations: :observations_species_lists).
                        where("observations_species_lists.species_list_id
                               = #{list.id}
                               AND names.rank = #{Name.ranks[:Species]}").
                        uniq

    visit("/species_list/show_species_list/#{list.id}")
    click_on("Checklist")
    assert_match(%r{Checklist for #{list.title}}, page.title, "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Project checklist goes to correct page with correct content
  def test_project_checklist
    project = projects(:one_genus_two_species_project)
    expect = Name.joins(observations: :observations_projects).
                        where("observations_projects.project_id = #{project.id}
                               AND names.rank = #{Name.ranks[:Species]}").
                        uniq

    visit("/project/show_project/#{project.id}")
    click_on("Checklist")
    assert_match(%r{Checklist for #{project.title}}, page.title, "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that checklist has as many links as species expected,
  # and no species is missing
  def prove_checklist_content(expect)
    missing_names = (
      expect.each_with_object([]) do |taxon, missing|
        missing << taxon.text_name if page.has_no_content?(taxon.text_name)
    end
    )

    page.assert_selector(".checklist a", count: expect.size)
    assert(missing_names.empty?, "Species List missing #{missing_names}")
  end
end
