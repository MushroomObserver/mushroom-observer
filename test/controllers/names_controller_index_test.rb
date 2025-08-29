# frozen_string_literal: true

require("test_helper")

class NamesControllerIndexTest < FunctionalTestCase
  tests NamesController
  include ObjectLinkHelper

  # ----------------------------
  #  Index tests.
  # ----------------------------
  #
  # Tests arranged as follows:
  # default subaction; then other subactions in order of index_active_params
  # miscellaneous tests using get(:index)
  def test_index
    login
    get(:index)

    assert_page_title(:NAMES.l)
    assert_select("#context_nav a[href='#{names_path}']", { count: 0 },
                  "right `tabs` should not link to All Names")
  end

  def test_index_with_non_default_sort
    check_index_sorting
  end

  def test_index_via_related_query_old_and_new_q
    user = dick
    query = Query.lookup_and_save(:Observation, by_users: user)
    new_query = Query.current_or_related_query(:Name, :Observation, query)
    new_query.save # have to save here so we can send it as `q`
    login

    # Temporary 2025-08-24: Check that the old alphabetized param still works
    q = new_query.id.alphabetize
    get(:index, params: { q: q })
    # Check that the controller sets a new permalink-style @query_param
    expected_q = { model: :Name, observation_query: { by_users: [user.id] } }
    assert_equal(assigns(:query_param), expected_q)
    assert_session_query_record_is_correct
    index_related_query_assertions(user)

    # Now check that the new param works the same
    get(:index, params: { q: expected_q })
    assert_equal(assigns(:query_param), expected_q)
    assert_session_query_record_is_correct
    index_related_query_assertions(user)
  end

  def index_related_query_assertions(user)
    assert_page_title(:NAMES.l)
    assert_displayed_filters(:query_observation_query.l)
    assert_displayed_filters("#{:query_by_users.l}: #{user.name}")
    result_names = Name.joins(:observations).with_correct_spelling.
                   where(observations: { user: user }).distinct
    # Check both that the count of results is right, and
    # that the new permalink version of the q param is in forward links
    assert_select(
      "#results a:match('href', ?)",
      %r{^#{names_path}/\d+},
      { count: result_names.count },
      "Wrong number of (correctly spelled) Names, or wrong `q`"
    )
  end

  def test_index_advanced_search_multiple_hits
    search_string = "Suil"
    query = Query.lookup_and_save(:Name, search_name: search_string)

    login
    params = { q: @controller.q_param(query), advanced_search: true }
    get(:index, params:)

    assert_response(:success)
    assert_select(
      "#results a:match('href', ?)", %r{^#{names_path}/\d+},
      { count: Name.where(Name[:text_name] =~ /#{search_string}/i).
                    with_correct_spelling.count },
      "Wrong number of (correctly spelled) Names"
    )
    assert_page_title(:NAMES.l)
    assert_displayed_filters("#{:query_search_name.l}: #{search_string}")
  end

  def test_index_advanced_search_one_hit
    search_string = "Stereum hirsutum"
    query = Query.lookup_and_save(:Name, search_name: search_string)
    assert(query.results.one?,
           "Test needs a string that has exactly one hit")

    login
    params = { q: @controller.q_param(query), advanced_search: true }
    get(:index, params:)
    assert_match(name_path(names(:stereum_hirsutum)), redirect_to_url,
                 "Wrong page")
  end

  def oklahoma_query
    Query.lookup_and_save(
      :Name, search_name: "Don't know",
             search_user: "myself",
             search_content: "Long pink stem and small pink cap",
             search_where: "Eastern Oklahoma"
    )
  end

  def test_index_advanced_search_no_hits
    query = oklahoma_query
    login
    params = { q: @controller.q_param(query), advanced_search: true }
    get(:index, params:)

    assert_page_title(:NAMES.l)
    assert_flash_text(:runtime_no_matches.l(type: :names.l))
  end

  # This test no longer makes sense with permalinks
  # def test_index_advanced_search_with_deleted_query
  #   query = oklahoma_query
  #   params = { q: @controller.q_param(query), advanced_search: true }
  #   query.record.delete

  #   login
  #   get(:index, params:)

  #   assert_redirected_to(search_advanced_path)
  # end

  def test_index_advanced_search_error
    query_no_conditions = Query.lookup_and_save(:Name)

    login
    params = { q: @controller.q_param(query_no_conditions),
               advanced_search: true }
    get(:index, params:)

    assert_flash_error(:runtime_no_conditions.l)
    assert_redirected_to(search_advanced_path)
  end

  def test_index_pattern_multiple_hits
    pattern = "Agaricus"

    login
    get(:index, params: { pattern: pattern })

    assert_page_title(:NAMES.l)
    assert_displayed_filters("#{:query_pattern.l}: #{pattern}")
    assert_select(
      "#results a:match('href', ?)", %r{^#{names_path}/\d+},
      { count: Name.where(Name[:text_name] =~ /#{pattern}/i).
                    with_correct_spelling.count },
      "Wrong number of (correctly spelled) Names"
    )
  end

  def test_index_pattern_id
    id = names(:agaricus).id

    login
    get(:index, params: { pattern: id })

    assert_redirected_to(name_path(id))
  end

  def test_index_pattern_help
    login
    get(:index, params: { pattern: "help:me" })

    assert_match(/unexpected term/i, @response.body)
  end

  def test_index_pattern_near_miss
    near_miss_pattern = "agaricis campestrus"
    assert_empty(Name.with_correct_spelling.
                      where(search_name: near_miss_pattern),
                 "Test needs a pattern without a correctly spelled exact match")
    near_misses = Name.with_correct_spelling.
                  where(Name[:search_name] =~ /agaric.s campestr.s/)

    login
    get(:index, params: { near_miss_pattern: })
    near_misses.each do |near_miss|
      assert_select("#results a[href*='names/#{near_miss.id}'] .display-name",
                    text: near_miss.search_name)
    end
  end

  def test_index_has_observations
    login
    get(:index, params: { has_observations: true })

    assert_response(:success)
    assert_page_title(:NAMES.l)
    assert_displayed_filters(:query_has_observations.l)
    assert_select(
      "#results a:match('href', ?)", %r{#{names_path}/\d+},
      { count: Name.joins(:observations).
                    with_correct_spelling.
                    distinct.count },
      "Wrong number of (correctly spelled) Names"
    )
    assert_select("#context_nav a[href='#{names_path}']", { count: 1 },
                  "right `tabs` should have a link to All Names")
  end

  def test_index_has_observations_by_letter
    letter = "A"
    names = Name.joins(:observations).
            with_correct_spelling. # website seems to behave this way
            where(Observation[:text_name].matches("#{letter}%"))
    assert(names.many?, "Test needs different letter")

    login
    get(:index, params: { has_observations: true, letter: letter })

    assert_response(:success)
    assert_page_title(:NAMES.l)
    assert_displayed_filters(:query_has_observations.l)
    names.each do |name|
      assert_select("#results a[href*='/names/#{name.id}'] .display-name",
                    name.search_name)
    end
  end

  def test_index_has_descriptions
    login
    get(:index, params: { has_descriptions: true })

    assert_response(:success)
    assert_page_title(:NAMES.l)
    assert_displayed_filters(:query_has_descriptions.l)
    assert_select("#results", { text: /not the default/ },
                  "Results should include non-default descriptions")
    assert_select(
      "#results a:match('href', ?)", %r{^#{names_path}/\d+},
      { count: Name.joins(:descriptions).
                    with_correct_spelling.
                    distinct.count },
      "Wrong number of (correctly spelled) Names"
    )
  end

  def test_index_needs_description
    login
    get(:index, params: { needs_description: true })

    assert_response(:success)
    assert_page_title(:NAMES.l)
    assert_displayed_filters(:query_needs_description.l)
    assert_select(
      "#results a:match('href', ?)", %r{^#{names_path}/\d+},
      # need length; count & size return a hash; needs_description is grouped
      { count: Name.with_correct_spelling.needs_description.length },
      "Wrong number of (correctly spelled) Names"
    )
  end

  def test_index_by_user_who_created_multiple_names
    user = dick

    login
    get(:index, params: { by_user: user.id })

    assert_page_title(:NAMES.l)
    assert_displayed_filters("#{:query_by_users.l}: #{user.name}")
    assert_select(
      "#results a:match('href', ?)", %r{^#{names_path}/\d+},
      { count: Name.where(user: user, correct_spelling_id: nil).count },
      "Wrong number of (correctly spelled) Names"
    )
  end

  def test_index_by_user_who_created_one_name
    user = roy
    assert(Name.where(user: user).none?)
    name = names(:boletus_edulis)
    name.user = user
    name.skip_notify = true
    name.save

    login
    get(:index, params: { by_user: user.id })

    assert_response(:redirect)
    assert_match(name_path(Name.where(user: user).first),
                 redirect_to_url)
  end

  def test_index_by_user_who_created_zero_names
    user = users(:zero_user)

    login
    get(:index, params: { by_user: user.id })

    assert_template("index")
    assert_flash_text(:runtime_no_matches.l(type: :names.l))
  end

  def test_index_by_user_bad_user_id
    bad_user_id = observations(:minimal_unknown_obs).id

    login
    get(:index, params: { by_user: bad_user_id })

    assert_flash_text(
      :runtime_object_not_found.l(type: "user", id: bad_user_id)
    )
    assert_redirected_to(names_path)
  end

  def test_index_by_editor_of_multiple_names
    user = dick
    make_dick_editor_of_addtional_name
    names_edited_by_user = Name.joins(:versions).
                           where.not(user: user).
                           where(versions: { user_id: user.id })
    assert(names_edited_by_user.many?)

    login
    get(:index, params: { by_editor: user })

    assert_page_title(:NAMES.l)
    assert_displayed_filters("#{:query_by_editor.l}: #{user.name}")
    assert_select("#results a:match('href',?)", %r{^/names/\d+},
                  { count: names_edited_by_user.count },
                  "Wrong number of results")
  end

  # A hack to make dick an editor of this name
  # He is the creator of the name and of a version
  # Changing the creator to rolf makes dick look like an editor
  def make_dick_editor_of_addtional_name
    name = names(:boletus_edulis)
    name.user = users(:rolf)
    name.skip_notify = true
    name.save
  end

  def test_index_by_editor_of_one_name
    user = dick
    names_edited_by_user = Name.joins(:versions).
                           where.not(user: user).
                           where(versions: { user_id: user.id })
    assert(names_edited_by_user.one?)

    login
    get(:index, params: { by_editor: user.id })

    assert_response(:redirect)
    assert_match(name_path(names_edited_by_user.first), redirect_to_url)
  end

  def test_index_by_editor_bad_user_id
    bad_user_id = observations(:minimal_unknown_obs).id

    login
    get(:index, params: { by_editor: bad_user_id })

    assert_flash_text(
      :runtime_object_not_found.l(type: "user", id: bad_user_id)
    )
    assert_redirected_to(names_path)
  end

  ################################################

  def ids_from_links(links)
    links.map do |l|
      l.to_s.match(%r{.*/([0-9]+)})[1].to_i
    end
  end

  def pagination_query_param
    query = Query.lookup_and_save(:Name, order_by: :name)
    @controller.q_param(query)
  end

  # None of our standard tests ever actually renders pagination_numbers
  # or letter_pagination_nav.  This tests all the above.
  def test_pagination_page1
    # Straightforward index of all names, showing first 10.
    login
    get(:test_index, params: { num_per_page: 10, q: pagination_query_param })
    assert_template("names/index")

    name_links = css_select(".list-group.name-index a")
    assert_equal(10, name_links.length)
    expected = Name.order(:sort_name, :author).limit(10).to_a
    assert_equal(expected.map(&:id), ids_from_links(name_links))

    url = @controller.url_for(controller: "/names", action: :show,
                              id: expected.first.id, only_path: true)
    assert_equal(name_links.first[:href], url)

    assert_link_in_html("Next", controller: "/names",
                                action: :test_index, num_per_page: 10,
                                q: pagination_query_param, page: 2)
  end

  def test_pagination_page2
    # Now go to the second page.
    login
    get(:test_index,
        params: { num_per_page: 10, page: 2, q: pagination_query_param })
    assert_template("names/index")

    name_links = css_select(".list-group.name-index a")
    assert_equal(10, name_links.length)
    expected = Name.order(:sort_name).limit(10).offset(10).to_a
    assert_equal(expected.map(&:id), ids_from_links(name_links))

    url = @controller.url_for(controller: "/names", action: :show,
                              id: expected.first.id, only_path: true)
    assert_equal(name_links.first[:href], url)

    assert_link_in_html("Previous", controller: "/names",
                                    action: :test_index, num_per_page: 10,
                                    q: pagination_query_param, page: 1)
  end

  def test_pagination_letter
    # Now try a letter.
    l_names = Name.where(Name[:text_name].matches("L%")).
              order(:text_name, :author).to_a
    login
    get(:test_index, params: { num_per_page: l_names.size,
                               letter: "L", q: pagination_query_param })
    assert_template("names/index")
    assert_select("#content")
    name_links = css_select(".list-group.name-index a")
    assert_equal(l_names.size, name_links.length)
    assert_equal(Set.new(l_names.map(&:id)),
                 Set.new(ids_from_links(name_links)))

    url = @controller.url_for(controller: "/names", action: :show,
                              id: l_names.first.id, only_path: true)
    assert_equal(name_links.first[:href], url)
    assert_select("a", text: "1", count: 0)
  end

  def test_pagination_letter_with_page
    l_names = Name.where(Name[:text_name].matches("L%")).
              order(:text_name, :author).to_a
    # Do it again, but make page size exactly one too small.
    l_names.pop
    login
    get(:test_index, params: { num_per_page: l_names.size,
                               letter: "L", q: pagination_query_param })
    assert_template("names/index")
    name_links = css_select(".list-group.name-index a")

    assert_equal(l_names.size, name_links.length)
    assert_equal(Set.new(l_names.map(&:id)),
                 Set.new(ids_from_links(name_links)))

    assert_link_in_html("Next", controller: "/names", action: :test_index,
                                q: pagination_query_param,
                                num_per_page: l_names.size,
                                letter: "L", page: 2)
  end

  def test_pagination_letter_with_page2
    l_names = Name.where(Name[:text_name].matches("L%")).
              order(:text_name, :author).to_a
    last_name = l_names.pop
    # Check second page.
    login
    get(:test_index, params: { num_per_page: l_names.size, letter: "L",
                               page: 2, q: pagination_query_param })
    assert_template("names/index")
    name_links = css_select(".list-group.name-index a")
    assert_equal(1, name_links.length)
    assert_equal([last_name.id], ids_from_links(name_links))

    assert_link_in_html("Previous", controller: "/names", action: :test_index,
                                    q: pagination_query_param,
                                    num_per_page: l_names.size,
                                    letter: "L", page: 1)
  end

  def test_pagination_with_anchors
    # Some cleverness is required to get pagination links to include anchors.
    login
    get(:test_index, params: { num_per_page: 10, test_anchor: "blah",
                               q: pagination_query_param })
    assert_link_in_html("Next", controller: "/names",
                                action: :test_index, num_per_page: 10,
                                q: pagination_query_param, page: 2,
                                test_anchor: "blah", anchor: "blah")
    # assert_link_in_html("A", controller: "/names",
    #                          action: :test_index, num_per_page: 10,
    #                          params: query_params, letter: "A",
    #                          test_anchor: "blah", anchor: "blah")
  end
end
