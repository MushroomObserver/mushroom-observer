# frozen_string_literal: true

require("test_helper")

class NamesControllerTest < FunctionalTestCase
  include ObjectLinkHelper

  # EMAIL TESTS, currently in Names, Locations and their Descriptions
  # Has to be defined on class itself, include doesn't seem to work
  def self.report_email(email)
    @@emails ||= []
    @@emails << email
  end

  def setup
    @new_pts  = 10
    @chg_pts  = 10
    @auth_pts = 100
    @edit_pts = 10
    @@emails = []
    super
  end

  def assert_email_generated
    assert_not_empty(@@emails, "Was expecting an email notification.")
  ensure
    @@emails = []
  end

  def assert_no_emails
    msg = @@emails.join("\n")
    assert(@@emails.empty?,
           "Wasn't expecting any email notifications; got:\n#{msg}")
  ensure
    @@emails = []
  end

  def create_name(name)
    parse = Name.parse_name(name)
    Name.new_name(parse.params)
  end

  ################################################
  #
  #   TEST INDEX
  #
  ################################################
  #
  # Tests of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of @index_subaction_param_keys
  # miscellaneous tests using get(:index)
  def test_index
    login
    get(:index)

    assert_displayed_title("Names by Name")
  end

  def test_index_with_non_default_sort
    by = "num_views"

    login
    get(:index, params: { by: by })

    assert_displayed_title("Names by Popularity")
  end

  def test_index_with_saved_query
    user = dick
    query = Query.lookup_and_save(:Observation, :by_user, user: user)
    q = query.id.alphabetize

    login
    get(:index, params: { q: q })

    assert_displayed_title("Names with Observations created by #{user.name}")
    # assert_displayed_title("Names with Matching Observations")
    assert_select(
      "#results a:match('href', ?)", %r{^#{names_path}/\d+},
      { count: Name.joins(:observations).with_correct_spelling.
               where(observations: { user: user }).distinct.count },
      "Wrong number of (correctly spelled) Names"
    )
  end

  def test_index_advanced_search_multiple_hits
    search_string = "Suil"
    query = Query.lookup_and_save(:Name, :advanced_search, name: search_string)

    login
    get(:index,
        params: @controller.query_params(query).merge(advanced_search: true))

    assert_response(:success)
    assert_displayed_title("Advanced Search")
    assert_select(
      "#results a:match('href', ?)", %r{^#{names_path}/\d+},
      { count: Name.where(Name[:text_name] =~ /#{search_string}/i).
                    with_correct_spelling.count },
      "Wrong number of (correctly spelled) Names"
    )
  end

  def test_index_advanced_search_one_hit
    search_string = "Stereum hirsutum"
    query = Query.lookup_and_save(:Name, :advanced_search, name: search_string)
    assert(query.results.one?,
           "Test needs a string that has exactly one hit")

    login
    get(:index,
        params: @controller.query_params(query).merge(advanced_search: true))
    assert_match(name_path(names(:stereum_hirsutum)), redirect_to_url,
                 "Wrong page")
  end

  def test_index_advanced_search_no_hits
    query = Query.lookup_and_save(:Name, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")

    login
    get(:index,
        params: @controller.query_params(query).merge({ advanced_search: "1" }))

    assert_select("title", { text: "#{:app_title.l}: Index" }, # metadata
                  "Wrong page or <title>text")
    assert_flash_text(:runtime_no_matches.l(type: :names.l))
  end

  def test_index_advanced_search_with_deleted_query
    query = Query.lookup_and_save(:Name, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    params = @controller.query_params(query).merge(advanced_search: true)
    query.record.delete

    login
    get(:index, params: params)

    assert_redirected_to(search_advanced_path)
  end

  def test_index_advanced_search_error
    query_without_conditions = Query.lookup_and_save(
      :Name, :advanced_search
    )

    login
    get(:index,
        params: @controller.query_params(query_without_conditions).
                            merge(advanced_search: true))

    assert_flash_error(:runtime_no_conditions.l)
    assert_redirected_to(search_advanced_path)
  end

  def test_index_pattern_multiple_hits
    pattern = "Agaricus"

    login
    get(:index, params: { pattern: pattern })

    assert_displayed_title("Names Matching ‘#{pattern}’")
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
      assert_select("#results a[href*='names/#{near_miss.id}']",
                    text: near_miss.search_name)
    end
  end

  def test_index_with_observations
    login
    get(:index, params: { with_observations: true })

    assert_response(:success)
    assert_displayed_title("Names with Observations")
    assert_select(
      "#results a:match('href', ?)", %r{#{names_path}/\d+},
      { count: Name.joins(:observations).
                    with_correct_spelling.
                    distinct.count },
      "Wrong number of (correctly spelled) Names"
    )
  end

  def test_index_with_observations_by_letter
    letter = "A"
    names = Name.joins(:observations).
            with_correct_spelling. # website seems to behave this way
            where(Observation[:text_name].matches("#{letter}%"))
    assert(names.many?, "Test needs different letter")

    login
    get(:index, params: { with_observations: true, letter: letter })

    assert_response(:success)
    assert_displayed_title("Names with Observations")
    names.each do |name|
      assert_select("#results a[href*='/names/#{name.id}']",
                    text: name.search_name)
    end
  end

  def test_index_with_descriptions
    login
    get(:index, params: { with_descriptions: true })

    assert_response(:success)
    assert_displayed_title("Names with Descriptions")
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

  def test_index_needing_descriptions
    login
    get(:index, params: { need_descriptions: true })

    assert_response(:success)
    assert_displayed_title("Selected Names")
    assert_select(
      "#results a:match('href', ?)", %r{^#{names_path}/\d+},
      # need length; count & size return a hash; description_needed is grouped
      { count: Name.description_needed.length },
      "Wrong number of (correctly spelled) Names"
    )
  end

  def test_index_by_user_who_created_multiple_names
    user = dick

    login
    get(:index, params: { by_user: user.id })

    assert_response(:success)
    assert_displayed_title("Names created by #{user.name}")
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
    name.save

    login
    get(:index, params: { by_user: user.id })

    assert_response(:redirect)
    assert_match(name_path(Name.where(user: user).first),
                 redirect_to_url)
  end

  def test_index_by_user_who_created_zero_locations
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

    assert_displayed_title("Names Edited by #{user.name}")
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

  def pagination_query_params
    query = Query.lookup_and_save(:Name, :all, by: :name)
    @controller.query_params(query)
  end

  # None of our standard tests ever actually renders pagination_links
  # or pagination_letters.  This tests all the above.
  def test_pagination_page1
    # Straightforward index of all names, showing first 10.
    query_params = pagination_query_params
    login
    get(:test_index, params: { num_per_page: 10 }.merge(query_params))
    # print @response.body
    assert_template("names/index")
    name_links = css_select(".table a")
    assert_equal(10, name_links.length)
    expected = Name.order("sort_name, author").limit(10).to_a
    assert_equal(expected.map(&:id), ids_from_links(name_links))
    # assert_equal(@controller.url_with_query(action: "show",
    #  id: expected.first.id, only_path: true), name_links.first.url)
    url = @controller.url_with_query(controller: "/names", action: :show,
                                     id: expected.first.id, only_path: true)
    assert_not_nil(name_links.first.to_s.index(url))
    assert_select("a", text: "1", count: 0)
    assert_link_in_html("2", controller: "/names",
                             action: :test_index, num_per_page: 10,
                             params: query_params, page: 2)
    assert_select("a", text: "Z", count: 0)
    assert_link_in_html("A", controller: "/names",
                             action: :test_index, num_per_page: 10,
                             params: query_params, letter: "A")
  end

  def test_pagination_page2
    # Now go to the second page.
    query_params = pagination_query_params
    login
    get(:test_index,
        params: { num_per_page: 10, page: 2 }.merge(query_params))
    assert_template("names/index")
    name_links = css_select(".table a")
    assert_equal(10, name_links.length)
    expected = Name.order("sort_name").limit(10).offset(10).to_a
    assert_equal(expected.map(&:id), ids_from_links(name_links))
    url = @controller.url_with_query(controller: "/names", action: :show,
                                     id: expected.first.id, only_path: true)
    assert_not_nil(name_links.first.to_s.index(url))

    assert_select("a", text: "2", count: 0)
    assert_link_in_html("1", controller: "/names",
                             action: :test_index, num_per_page: 10,
                             params: query_params, page: 1)
    assert_select("a", text: "Z", count: 0)
    assert_link_in_html("A", controller: "/names",
                             action: :test_index, num_per_page: 10,
                             params: query_params, letter: "A")
  end

  def test_pagination_letter
    # Now try a letter.
    query_params = pagination_query_params
    l_names = Name.where(Name[:text_name].matches("L%")).
              order("text_name, author").to_a
    login
    get(:test_index, params: { num_per_page: l_names.size,
                               letter: "L" }.merge(query_params))
    assert_template("names/index")
    assert_select("#content")
    name_links = css_select(".table a")
    assert_equal(l_names.size, name_links.length)
    assert_equal(Set.new(l_names.map(&:id)),
                 Set.new(ids_from_links(name_links)))

    url = @controller.url_with_query(controller: "/names", action: :show,
                                     id: l_names.first.id, only_path: true)
    assert_not_nil(name_links.first.to_s.index(url))
    assert_select("a", text: "1", count: 0)
    assert_select("a", text: "Z", count: 0)

    assert_link_in_html("A", controller: "/names",
                             action: :test_index, params: query_params,
                             num_per_page: l_names.size, letter: "A")
  end

  def test_pagination_letter_with_page
    query_params = pagination_query_params
    l_names = Name.where(Name[:text_name].matches("L%")).
              order("text_name, author").to_a
    # Do it again, but make page size exactly one too small.
    l_names.pop
    login
    get(:test_index, params: { num_per_page: l_names.size,
                               letter: "L" }.merge(query_params))
    assert_template("names/index")
    name_links = css_select(".table a")

    assert_equal(l_names.size, name_links.length)
    assert_equal(Set.new(l_names.map(&:id)),
                 Set.new(ids_from_links(name_links)))

    assert_select("a", text: "1", count: 0)

    assert_link_in_html("2", controller: "/names",
                             action: :test_index, params: query_params,
                             num_per_page: l_names.size,
                             letter: "L", page: 2)

    assert_select("a", text: "3", count: 0)
  end

  def test_pagination_letter_with_page2
    query_params = pagination_query_params
    l_names = Name.where(Name[:text_name].matches("L%")).
              order("text_name, author").to_a
    last_name = l_names.pop
    # Check second page.
    login
    get(:test_index, params: { num_per_page: l_names.size, letter: "L",
                               page: 2 }.merge(query_params))
    assert_template("names/index")
    name_links = css_select(".table a")
    assert_equal(1, name_links.length)
    assert_equal([last_name.id], ids_from_links(name_links))
    assert_select("a", text: "2", count: 0)
    assert_link_in_html("1", controller: "/names",
                             action: :test_index, params: query_params,
                             num_per_page: l_names.size,
                             letter: "L", page: 1)
    assert_select("a", text: "3", count: 0)
  end

  def test_pagination_with_anchors
    query_params = pagination_query_params
    # Some cleverness is required to get pagination links to include anchors.
    login
    get(:test_index, params: {
      num_per_page: 10,
      test_anchor: "blah"
    }.merge(query_params))
    assert_link_in_html("2", controller: "/names",
                             action: :test_index, num_per_page: 10,
                             params: query_params, page: 2,
                             test_anchor: "blah", anchor: "blah")
    assert_link_in_html("A", controller: "/names",
                             action: :test_index, num_per_page: 10,
                             params: query_params, letter: "A",
                             test_anchor: "blah", anchor: "blah")
  end

  ################################################
  #
  #   SHOW
  #
  ################################################

  def test_show_name
    assert_equal(0, QueryRecord.count)
    login
    get(:show, params: { id: names(:coprinus_comatus).id })
    assert_template("show")
    # Creates three for children and all four observations sections,
    # but one never used. (? Now 4 - AN 20240107)
    assert_equal(4, QueryRecord.count)

    get(:show, params: { id: names(:coprinus_comatus).id })
    assert_template("show")
    # Should re-use all the old queries.
    assert_equal(4, QueryRecord.count)

    get(:show, params: { id: names(:agaricus_campestris).id })
    assert_template("show")
    # Needs new queries this time. (? Up from 7 - AN 20240107)
    assert_equal(9, QueryRecord.count)

    # Agarcius: has children taxa.
    get(:show, params: { id: names(:agaricus).id })
    assert_template("show")
  end

  def test_show_name_species_with_icn_id
    # Name's icn_id is filled in
    name = names(:coprinus_comatus)
    login
    get(:show, params: { id: name.id })
    assert_select(
      "body a[href='#{index_fungorum_record_url(name.icn_id)}']", true,
      "Page is missing a link to IF record"
    )
    assert_select(
      "body a[href='#{mycobank_record_url(name.icn_id)}']", true,
      "Page is missing a link to MB record"
    )
    assert_select(
      "body a[href='#{species_fungorum_gsd_synonymy(name.icn_id)}']", true,
      "Page is missing a link to GSD Synonymy record"
    )
  end

  def test_show_name_genus_with_icn_id
    # Name's icn_id is filled in
    name = names(:tubaria)
    login
    get(:show, params: { id: name.id })
    assert_select(
      "body a[href='#{species_fungorum_sf_synonymy(name.icn_id)}']", true,
      "Page is missing a link to SF Synonymy record"
    )
  end

  def test_show_name_icn_id_missing
    # Name is registrable, but icn_id is not filled in
    name = names(:coprinus)
    label = :ICN_ID.l.to_s
    login
    get(:show, params: { id: name.id })

    assert_select(
      "#nomenclature", /#{label}.*#{:show_name_icn_id_missing.l}/m,
      "Nomenclature section missing an ICN id label and/or " \
      "'#{:show_name_icn_id_missing.l}' note"
    )
    assert_select(
      "#nomenclature a:match('href',?)",
      /#{index_fungorum_basic_search_url}/,
      { count: 1 },
      "Nomenclature section should have link to IF search"
    )
    assert_select(
      "#nomenclature a:match('href',?)", /#{mycobank_name_search_url(name)}/,
      { count: 1 },
      "Nomenclature section should have link to MB search"
    )

    assert_select(
      "body a[href='#{index_fungorum_record_url(name.icn_id)}']", false,
      "Page should not have link to IF record"
    )
  end

  def test_show_name_searchable_in_registry
    name = names(:boletus_edulis_group)
    login
    get(:show, params: { id: name.id })

    # Name isn't registrable; it shouldn't have an icn_id label or record link
    assert(/#{:ICN_ID.l}/ !~ @response.body,
           "Page should not have ICN identifier label")
    assert_select(
      "body a[href='#{index_fungorum_record_url(name.icn_id)}']", false,
      "Page should not have link to IF record"
    )

    # but it makes sense to link to search pages in fungal registries
    assert_select(
      "#nomenclature a:match('href',?)",
      /#{index_fungorum_basic_search_url}/,
      { count: 1 },
      "Nomenclature section should have link to IF search"
    )
    assert_select(
      "#nomenclature a:match('href',?)", /#{mycobank_basic_search_url}/,
      { count: 1 },
      "Nomenclature section should have link to MB search"
    )
  end

  def test_show_name_icn_id_unregistrable
    # Name is not registrable (cannot have an icn number)
    name = names(:eukarya)
    login
    get(:show, params: { id: name.id })
    assert(/#{:ICN_ID.l}/ !~ @response.body,
           "Page should not have ICN identifier label")
  end

  def test_show_name_with_eol_link
    login
    get(:show, params: { id: names(:abortiporus_biennis_for_eol).id })
    assert_template("show")
  end

  def test_name_external_links_exist
    login
    get(:show, params: { id: names(:coprinus_comatus).id })

    assert_select("a[href *= 'images.google.com']")
    assert_select("a[href *= 'mycoportal.org']")
  end

  def test_show_name_locked
    name = Name.where(locked: true).first
    # login
    # get(:show, params: { id: name.id })
    # assert_synonym_links(name, 0, 0, 0)
    login("rolf")
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 0, 0, 0)
    make_admin("mary")
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 0, 1, 1)

    Name.update(name.id, deprecated: true)
    logout
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 0, 0, 0)
    login("rolf")
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 0, 0, 0)
    make_admin("mary")
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 1, 0, 1)
  end

  def test_show_missing_created_at
    name = names(:coprinus_comatus)

    footer_created_by =
      # I'd like to do something like the commented out lines,
      # but they thhrow an error at
      # app/helpers/object_link_helper.rb:124:in `user_link'
      # footer_created_by = :footer_created_by.t(
      #   user: user_link(name.user),
      #   date: name.created_at.web_time
      # ).to_s
      "<strong>Created:</strong> #{name.created_at.web_time} " \
      "<strong>by</strong> #{name.user.name} (#{name.user.login}"

    # zap created_at directly in the db, else Rails will also change updated_at
    name.update_columns(created_at: nil)

    login
    get(:show, params: { id: name.id })

    assert_no_match(
      footer_created_by, @response.body,
      "Footer should omit `#{:Created.l} line if created_at is absent"
    )
  end

  def test_show_new_version_missing_updated_at
    name = names(:coprinus_comatus)
    assert_operator(name.version, :>, 1,
                    "Test needs a fixture with multiple versions")
    footer_updated_at =
      :footer_last_updated_at.t(date: name.updated_at.web_time).to_s

    # bork updated_at directly in the db, else Rails will add it
    name.update_columns(updated_at: nil)
    login
    get(:show, params: { id: name.id })

    assert_no_match(
      footer_updated_at, @response.body,
      "Footer should omit #{:modified.l} date if updated_at absent"
    )
  end

  def test_show_new_version_missing_user
    name = names(:coprinus_comatus)
    name_last_version = name.versions.last
    assert_operator(name_last_version.version, :>, 1,
                    "Test needs a fixture with multiple versions")
    last_user = User.find(name_last_version.user_id)
    footer_last_updated_by =
      # I'd like to do something like the commented out lines,
      # but they thhrow an error at
      #    app/helpers/object_link_helper.rb:124:in `user_link'
      # -- jdc 2023-05-17
      # (:footer_last_updated_by.t(
      #    user: user_link(last_user),
      #    date: name_last_version.updated_at.web_time)
      # ).to_s
      "<strong>Last modified:</strong> " \
      "#{name_last_version.updated_at.web_time} " \
      "<strong>by</strong> #{last_user.name} (#{last_user.login})"

    # bork user directly in the db, else Rails will also change updated_at
    name_last_version.update_columns(user_id: nil)

    login
    get(:show, params: { id: name.id })

    assert_no_match(
      footer_last_updated_by, @response.body,
      "Footer should omit #{:modified.l} by if updated_at absent"
    )
  end

  def assert_synonym_links(name, approve, deprecate, edit)
    assert_select("a[href*=?]", approve_name_synonym_form_path(name.id),
                  count: approve)
    assert_select("a[href*=?]", deprecate_name_synonym_form_path(name.id),
                  count: deprecate)
    assert_select("a[href*=?]", edit_name_synonyms_path(name.id),
                  count: edit)
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  # NOTE: The interest links are GET paths because email.
  def test_interest_in_show_name
    peltigera = names(:peltigera)
    login("rolf")

    # No interest in this name yet.
    get(:show, params: { id: peltigera.id })
    assert_response(:success)
    assert_image_link_in_html(/watch.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: 1))
    assert_image_link_in_html(/ignore.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: -1))

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.create(target: peltigera, user: rolf, state: true)
    get(:show, params: { id: peltigera.id })
    assert_response(:success)
    assert_image_link_in_html(/halfopen.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: 0))
    assert_image_link_in_html(/ignore.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: -1))

    # Destroy that interest, create new one with interest off.
    Interest.where(user_id: rolf.id).last.destroy
    Interest.create(target: peltigera, user: rolf, state: false)
    get(:show, params: { id: peltigera.id })
    assert_response(:success)
    assert_image_link_in_html(/halfopen.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: 0))
    assert_image_link_in_html(/watch.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: 1))
  end

  def test_next_and_prev
    names = Name.order("text_name, author").to_a
    name12 = names[12]
    name13 = names[13]
    name14 = names[14]
    login
    get(:show, params: { flow: "next", id: name12.id })
    q = @controller.query_params(QueryRecord.last)
    assert_redirected_to(name_path(name13.id, params: q))
    get(:show, params: { flow: "next", id: name13.id })
    assert_redirected_to(name_path(name14.id, params: q))
    get(:show, params: { flow: "prev", id: name14.id })
    assert_redirected_to(name_path(name13.id, params: q))
    get(:show, params: { flow: "prev", id: name13.id })
    assert_redirected_to(name_path(name12.id, params: q))
  end

  def test_next_and_prev2
    query = Query.lookup_and_save(:Name, :pattern_search, pattern: "lactarius")
    q = @controller.query_params(query)

    name1 = query.results[0]
    name2 = query.results[1]
    name3 = query.results[-2]
    name4 = query.results[-1]

    login
    get(:show, params: q.merge(id: name1.id, flow: :next))
    assert_redirected_to(name_path(name2.id, params: q))
    get(:show, params: q.merge(id: name3.id, flow: :next))
    assert_redirected_to(name_path(name4.id, params: q))
    get(:show, params: q.merge(id: name4.id, flow: :next))
    assert_redirected_to(name_path(name4.id, params: q))
    assert_flash_text(/no more/i)

    get(:show, params: q.merge(id: name4.id, flow: :prev))
    assert_redirected_to(name_path(name3.id, params: q))
    get(:show, params: q.merge(id: name2.id, flow: :prev))
    assert_redirected_to(name_path(name1.id, params: q))
    get(:show, params: q.merge(id: name1.id, flow: :prev))
    assert_redirected_to(name_path(name1.id, params: q))
    assert_flash_text(/no more/i)
  end

  # ----------------------------
  #  Create name.
  # ----------------------------

  def test_create_name_get
    requires_login(:new)
    assert_form_action(action: :create)
    assert_select("form #name_icn_id", { count: 1 },
                  "Form is missing field for icn_id")
  end

  def test_create_name_post
    text_name = "Amanita velosa"
    assert_not(Name.find_by(text_name: text_name))
    author = "(Peck) Lloyd"
    icn_id = 485_288
    params = {
      name: {
        icn_id: icn_id,
        text_name: text_name,
        author: author,
        rank: "Species",
        citation: "??Mycol. Writ.?? 9(15). 1898."
      }
    }
    post_requires_login(:create, params)

    assert(name = Name.find_by(text_name: text_name))
    assert_redirected_to(name_path(name.id))
    assert_equal(10 + @new_pts, rolf.reload.contribution)
    assert_equal(icn_id, name.icn_id)
    assert_equal(author, name.author)
    assert_equal(rolf, name.user)
  end

  def test_create_name_blank
    login("rolf")
    params = {
      name: {
        text_name: "",
        author: "",
        rank: "Species",
        citation: ""
      }
    }
    # Just make sure it doesn't crash!
    post(:create, params: params)
  end

  def test_create_name_existing
    name = names(:conocybe_filaris)
    text_name = name.text_name
    count = Name.count
    params = {
      name: {
        text_name: text_name,
        author: "",
        rank: "Species",
        citation: ""
      }
    }
    login("rolf")
    post(:create, params: params)

    assert_response(:success)
    assert_equal(count, Name.count,
                 "Shouldn't have created #{Name.last.search_name.inspect}.")
    names = Name.where(text_name: text_name)
    assert_obj_arrays_equal([names(:conocybe_filaris)], names)
    assert_equal(10, rolf.reload.contribution)
  end

  def test_create_name_icn_already_used
    old_name = names(:coprinus_comatus)
    assert_true(old_name.icn_id.present?)
    name_count = Name.count
    rss_log_count = RssLog.count
    params = {
      name: {
        icn_id: old_name.icn_id.to_s,
        text_name: "Something else",
        author: "(Thank You) Why Not",
        rank: "Species",
        citation: "I'll pass"
      }
    }
    login("mary")
    post(:create, params: params)
    assert_response(:success)
    assert_equal(name_count, Name.count,
                 "Shouldn't have created #{Name.last.search_name.inspect}.")
    assert_equal(rss_log_count, RssLog.count,
                 "Shouldn't have created an RSS log! #{RssLog.last.inspect}.")
  end

  def test_create_name_matching_multiple_names
    desired_name = names(:coprinellus_micaceus_no_author)
    text_name = desired_name.text_name
    params = {
      name: {
        text_name: text_name,
        author: "",
        rank: desired_name.rank,
        citation: desired_name.citation
      }
    }
    flash_text = :create_name_multiple_names_match.t(str: text_name)
    count = Name.count
    login("rolf")
    post(:create, params: params)

    assert_flash_text(flash_text)
    assert_response(:success)
    assert_equal(count, Name.count,
                 "Shouldn't have created #{Name.last.search_name.inspect}.")
  end

  def test_create_name_unauthored_authored
    # Prove user can't create authored non-"Group" Name
    # if unauthored one exists.
    old_name_count = Name.count
    name = names(:strobilurus_diminutivus_no_author)
    params = {
      name: {
        text_name: name.text_name,
        author: "Author",
        rank: name.rank,
        status: name.status
      }
    }
    user = users(:rolf)
    login(user.login)
    post(:create, params: params)

    assert_response(:success)
    flash_text = :runtime_name_create_already_exists.t(name: name.display_name)
    assert_flash_text(flash_text)
    assert_empty(name.reload.author)
    assert_equal(old_name_count, Name.count)
    expect = user.contribution
    assert_equal(expect, user.reload.contribution)

    # And vice versa. Prove user can't create unauthored non-"Group" Name
    # if authored one exists.
    name = names(:coprinus_comatus)
    author = name.author
    params = {
      name: {
        text_name: name.text_name,
        author: "",
        rank: name.rank,
        status: name.status
      }
    }
    post(:create, params: params)

    assert_response(:success)
    flash_text = :runtime_name_create_already_exists.t(name: name.display_name)
    assert_flash_text(flash_text)
    assert_equal(author, name.reload.author)
    assert_equal(old_name_count, Name.count)
    expect = user.contribution
    assert_equal(expect, user.reload.contribution)
  end

  def test_create_name_authored_group_unauthored_exists
    name = names(:unauthored_group)
    text_name = name.text_name
    params = {
      name: {
        text_name: text_name,
        author: "Author",
        rank: "Group",
        citation: ""
      }
    }
    login("rolf")
    old_contribution = rolf.contribution
    post(:create, params: params)

    assert(authored_name = Name.find_by(search_name: "#{text_name} Author"))
    assert_flash_success
    assert_redirected_to(name_path(authored_name.id))
    assert(Name.exists?(name.id))
    assert_equal(old_contribution + SiteData::FIELD_WEIGHTS[:names],
                 rolf.reload.contribution)
  end

  def test_create_name_bad_name
    text_name = "Amanita Pantherina"
    name = Name.find_by(text_name: text_name)
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        rank: "Species"
      }
    }
    login("rolf")
    post(:create, params: params)
    assert_template("names/new")
    assert_template("names/_form")
    # Should fail and no name should get created
    assert_nil(Name.find_by(text_name: text_name))
    assert_form_action(action: :create)
  end

  def test_create_name_author_trailing_comma
    text_name = "Inocybe magnifolia"
    name = Name.find_by(text_name: text_name)
    punct = "!"
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        author: "Matheny, Aime & T.W. Henkel,",
        rank: :Species
      }
    }
    login("rolf")

    assert_no_difference(
      "Name.count",
      "A Name should not be created when Author ends with #{punct}"
    ) do
      post(:create, params: params)
    end
    assert_flash_error(:name_error_field_end.l)
  end

  def test_create_name_citation_leading_commma
    text_name = "Coprinopsis nivea"
    name = Name.find_by(text_name: text_name)
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        author: "(Pers.) Redhead, Vilgalys & Moncalvo",
        citation: ", in Redhead, Taxon 50(1): 229 (2001)",
        rank: :Species
      }
    }
    login("rolf")

    assert_no_difference(
      "Name.count",
      "A Name should not be created when Citation starts with ','"
    ) do
      post(:create, params: params)
    end
    assert_flash_error(:name_error_field_start.l)
  end

  def test_create_name_author_limit
    # Prove author :limit is number of characters, not bytes
    text_name = "Max-size-author"
    # String with author_limit multi-byte characters, and > author_limit bytes
    author    = "Á#{"æ" * (Name.author_limit - 1)}"
    params = {
      name: {
        text_name: text_name,
        author: author,
        rank: "Genus"
      }
    }
    post_requires_login(:create, params)

    assert(name = Name.find_by(text_name: text_name), "Failed to create name")
    assert_equal(author, name.author)
  end

  def test_create_name_alt_rank
    text_name = "Ustilaginomycetes"
    name = Name.find_by(text_name: text_name)
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        rank: "Phylum"
      }
    }
    login("rolf")
    post(:create, params: params)
    # Now try to find it
    assert(name = Name.find_by(text_name: text_name))
    assert_redirected_to(name_path(name.id))
  end

  def test_create_name_with_many_implicit_creates
    text_name = "Genus spec ssp. subspecies v. variety forma form"
    text_name2 = "Genus spec subsp. subspecies var. variety f. form"
    name = Name.find_by(text_name: text_name)
    count = Name.count
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        rank: "Form"
      }
    }
    login("rolf")
    post(:create, params: params)
    # Now try to find it
    assert(name = Name.find_by(text_name: text_name2))
    assert_redirected_to(name_path(name.id))
    assert_equal(count + 5, Name.count)
  end

  def test_create_species_under_ambiguous_genus
    login("dick")
    agaricus1 = names(:agaricus)
    agaricus1.change_author("L.")
    agaricus1.save
    Name.create!(
      text_name: "Agaricus",
      search_name: "Agaricus Raf.",
      sort_name: "Agaricus Raf.",
      display_name: "**__Agaricus__** Raf.",
      author: "Raf.",
      rank: "Genus",
      deprecated: false,
      correct_spelling: nil
    )
    agarici = Name.where(text_name: "Agaricus")
    assert_equal(2, agarici.length)
    assert_equal("L.", agarici.first.author)
    assert_equal("Raf.", agarici.last.author)
    params = {
      name: {
        text_name: "Agaricus endoxanthus",
        author: "",
        rank: "Species",
        citation: "",
        deprecated: "false"
      }
    }
    post(:create, params: params)
    assert_flash_success
    assert_redirected_to(name_path(Name.last.id))
  end

  def test_create_family
    login("dick")
    params = {
      name: {
        text_name: "Lecideaceae",
        author: "",
        rank: "Genus",
        citation: "",
        deprecated: "false"
      }
    }
    post(:create, params: params)
    assert_flash_error
    params[:name][:rank] = "Family"
    post(:create, params: params)
    assert_flash_success
  end

  def test_create_variety
    text_name = "Pleurotus djamor var. djamor"
    author    = "(Fr.) Boedijn"
    params = {
      name: {
        text_name: "#{text_name} #{author}",
        author: "",
        rank: "Variety",
        deprecated: "false"
      }
    }
    login("katrina")
    post(:create, params: params)

    assert(name = Name.find_by(text_name: text_name))
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    assert_equal("Variety", name.rank)
    assert_equal("#{text_name} #{author}", name.search_name)
    assert_equal(author, name.author)
    assert(Name.find_by(text_name: "Pleurotus djamor"))
    assert(Name.find_by(text_name: "Pleurotus"))
  end

  # ----------------------------
  #  Edit name -- without merge
  # ----------------------------

  def test_edit_name_get
    name = names(:coprinus_comatus)
    params = { id: name.id.to_s }
    requires_login(:edit, params)
    assert_form_action(action: :update, id: name.id.to_s)
    assert_select("form #name_icn_id", { count: 1 },
                  "Form is missing field for icn_id")
  end

  def test_edit_name_post
    name = names(:conocybe_filaris)
    assert_equal("Conocybe filaris", name.text_name)
    assert_blank(name.author)
    assert_equal(1, name.version)
    params = {
      id: name.id,
      name: {
        text_name: "Conocybe filaris",
        author: "(Fr.) Kühner",
        rank: "Species",
        citation: "__Le Genera Galera__, 139. 1935.",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    put_requires_login(:update, params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_equal(10, rolf.reload.contribution)
    assert_equal("(Fr.) Kühner", name.reload.author)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.display_name)
    assert_equal("Conocybe filaris (Fr.) Kühner", name.search_name)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(rolf, name.user)
  end

  def test_edit_name_no_changes
    name = names(:conocybe_filaris)
    text_name = name.text_name
    author = name.author
    rank = name.rank
    citation = name.citation
    deprecated = name.deprecated
    params = {
      id: name.id,
      name: {
        text_name: text_name,
        author: author,
        rank: rank,
        citation: citation,
        deprecated: (deprecated ? "true" : "false")
      }
    }
    user = name.user
    contribution = user.contribution
    login(user.login)
    put(:update, params: params)

    assert_flash_text(:runtime_no_changes.l)
    assert_redirected_to(name_path(name.id))
    assert_equal(text_name, name.reload.text_name)
    assert_equal(author, name.author)
    assert_equal(rank, name.rank)
    assert_equal(citation, name.citation)
    assert_equal(deprecated, name.deprecated)
    assert_equal(user, name.user)
    assert_equal(contribution, user.contribution)
  end

  # This catches a bug that was happening when editing a name that was in use.
  # In this case text_name and author are missing, confusing edit_name.
  def test_edit_name_post_name_and_author_missing
    names(:conocybe).destroy
    name = names(:conocybe_filaris)
    params = {
      id: name.id,
      name: {
        rank: "Species",
        citation: "__Le Genera Galera__, 139. 1935.",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    assert_equal("", name.reload.author)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(rolf, name.user)
    assert_equal(10, rolf.reload.contribution)
  end

  def test_edit_name_unchangeable_plus_admin_email
    name = names(:other_user_owns_naming_name)
    user = name.user
    contribution = user.contribution
    # Change the first word
    desired_text_name = name.text_name.
                        sub(/\S+/, "Big-change-to-force-email-to-admin")
    params = {
      id: name.id,
      name: {
        text_name: desired_text_name,
        author: "",
        rank: name.rank,
        deprecated: "false"
      }
    }
    login(name.user.login)
    put(:update, params: params)
    # This does not generate a emails_name_change_request_path email,
    # both because this name has no dependents,
    # and because the email form requires a POST.
    assert(@@emails.one?)
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_equal(desired_text_name, name.reload.search_name)
    assert_equal(contribution, user.reload.contribution)
  end

  def test_edit_name_post_just_change_notes
    # has blank notes
    name = names(:conocybe_filaris)
    past_names = name.versions.size
    new_notes = "Add this to the notes."
    params = {
      id: name.id,
      name: {
        text_name: "Conocybe filaris",
        author: "",
        rank: "Species",
        citation: "",
        notes: new_notes,
        deprecated: (name.deprecated ? "true" : "false")

      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    assert_equal(@new_pts, rolf.reload.contribution)
    assert_equal(new_notes, name.reload.notes)
    assert_equal(past_names + 1, name.versions.size)
  end

  def test_edit_deprecated_name_remove_author
    name = names(:lactarius_alpigenes)
    assert(name.deprecated)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: "",
        rank: "Species",
        citation: "new citation",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login("mary")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_email_generated
    assert(Name.exists?(text_name: "Lactarius"))
    # points for changing Lactarius alpigenes
    assert_equal(@new_pts + @chg_pts, mary.reload.contribution)
    assert(name.reload.deprecated)
    assert_equal("new citation", name.citation)
  end

  def test_edit_name_add_author
    name = names(:strobilurus_diminutivus_no_author)
    old_text_name = name.text_name
    new_author = "Desjardin"
    params = {
      id: name.id,
      name: {
        text_name: old_text_name,
        author: new_author,
        rank: "Species",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login("mary")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_equal(@new_pts + @chg_pts, mary.reload.contribution)
    assert_equal(new_author, name.reload.author)
    assert_equal(old_text_name, name.text_name)
  end

  # Prove that user can change name -- without merger --
  # if there's no exact match to desired Name
  def test_edit_name_remove_author_no_exact_match
    name = names(:amanita_baccata_arora)
    params = {
      id: name.id,
      name: {
        text_name: names(:coprinus_comatus).text_name,
        author: "",
        rank: names(:coprinus_comatus).rank,
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login(name.user.login)
    put(:update, params: params)

    assert_redirected_to(name_path(name.id))
    assert_flash_success
    assert_empty(name.reload.author)
    assert_email_generated
  end

  def test_edit_name_misspelling
    login("rolf")

    # Prove we can clear misspelling by unchecking "misspelt" box
    name = names(:petigera)
    assert_true(name.reload.is_misspelling?)
    assert_names_equal(names(:peltigera), name.correct_spelling)
    assert_true(name.deprecated)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: "true",
        misspelling: ""
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_false(name.reload.is_misspelling?)
    assert_nil(name.correct_spelling)
    assert_true(name.deprecated)
    assert_redirected_to(name_path(name.id))

    # Prove we can deprecate and call a name misspelt by checking box and
    # entering correct spelling.
    Name.update(name.id, deprecated: false)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: "false",
        misspelling: "1",
        correct_spelling: "Peltigera"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_true(name.reload.is_misspelling?)
    assert_equal("__Petigera__", name.display_name)
    assert_names_equal(names(:peltigera), name.correct_spelling)
    assert_true(name.deprecated)
    assert_redirected_to(name_path(name.id))

    # Prove we cannot correct misspelling with unrecognized Name
    name = names(:suilus)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: (name.deprecated ? "true" : "false"),
        misspelling: 1,
        correct_spelling: "Qwertyuiop"
      }
    }
    put(:update, params: params)
    assert_flash_error
    assert(name.reload.is_misspelling?)

    # Prove we cannot correct misspelling with same Name
    name = names(:suilus)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: (name.deprecated ? "true" : "false"),
        misspelling: 1,
        correct_spelling: name.text_name
      }
    }
    put(:update, params: params)
    assert_flash_error
    assert(name.reload.is_misspelling?)

    # Prove we can swap misspelling and correct_spelling
    # Change "Suillus E.B. White" to "Suilus E.B. White"
    old_misspelling = names(:suilus)
    old_correct_spelling = old_misspelling.correct_spelling
    params = {
      id: old_correct_spelling.id,
      name: {
        text_name: old_correct_spelling.text_name,
        author: old_correct_spelling.author,
        rank: old_correct_spelling.rank,
        deprecated: (old_correct_spelling.deprecated ? "true" : "false"),
        misspelling: 1,
        correct_spelling: old_misspelling.text_name
      }
    }
    put(:update, params: params)
    # old_correct_spelling's spelling status and deprecation should change
    assert(old_correct_spelling.reload.is_misspelling?)
    assert_equal(old_misspelling, old_correct_spelling.correct_spelling)
    assert(old_correct_spelling.deprecated)
    # old_misspelling's spelling status should change but deprecation should not
    assert_not(old_misspelling.reload.is_misspelling?)
    assert_empty(old_misspelling.correct_spelling)
    assert(old_misspelling.deprecated)
  end

  def test_edit_name_by_user_who_doesnt_own_name
    name = names(:macrolepiota_rhacodes)
    name_owner = name.user
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: "Species",
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    put(:update, params: params)

    assert_flash_warning
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    assert_equal(@new_pts, rolf.reload.contribution)
    # (But owner remains of course.)
    assert_equal(name_owner, name.reload.user)
  end

  def test_edit_name_chain_to_approve_and_deprecate
    login("rolf")
    name = names(:lactarius_alpigenes)
    params = {
      id: name.id,
      name: {
        rank: name.rank,
        text_name: name.text_name,
        author: name.author,
        citation: name.citation,
        notes: name.notes
      }
    }

    # No change: go to show_name, warning.
    params[:name][:deprecated] = "true"
    put(:update, params: params)
    assert_flash_warning
    assert_redirected_to(name_path(name.id))
    assert_no_emails

    # Change to accepted: go to approve_name, no flash.
    params[:name][:deprecated] = "false"
    put(:update, params: params)
    assert_no_flash
    assert_redirected_to(approve_name_synonym_form_path(name.id))

    # Change to deprecated: go to deprecate_name, no flash.
    name.change_deprecated(false)
    name.save
    params[:name][:deprecated] = "true"
    put(:update, params: params)
    assert_no_flash
    assert_redirected_to(deprecate_name_synonym_form_path(name.id))
  end

  def test_edit_name_with_umlaut
    login("dick")
    names = Name.find_or_create_name_and_parents("Xanthoparmelia coloradoensis")
    names.each(&:save)
    name = names.last
    assert_equal("Xanthoparmelia coloradoensis", name.text_name)
    assert_equal("Xanthoparmelia coloradoensis", name.search_name)
    assert_equal("**__Xanthoparmelia coloradoensis__**", name.display_name)

    get(:edit, params: { id: name.id })
    assert_input_value("name_text_name", "Xanthoparmelia coloradoensis")
    assert_textarea_value("name_author", "")

    params = {
      id: name.id,
      name: {
        # (test what happens if user puts author in wrong field)
        text_name: "Xanthoparmelia coloradoënsis (Gyelnik) Hale",
        author: "",
        rank: "Species",
        deprecated: "false"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    name.reload
    assert_equal("Xanthoparmelia coloradoensis", name.text_name)
    assert_equal("Xanthoparmelia coloradoensis (Gyelnik) Hale",
                 name.search_name)
    assert_equal("**__Xanthoparmelia coloradoënsis__** (Gyelnik) Hale",
                 name.display_name)

    get(:edit, params: { id: name.id })
    assert_input_value("name_text_name", "Xanthoparmelia coloradoënsis")
    assert_textarea_value("name_author", "(Gyelnik) Hale")

    params[:name][:text_name] = "Xanthoparmelia coloradoensis"
    params[:name][:author] = ""
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_email_generated
    name.reload
    assert_equal("Xanthoparmelia coloradoensis", name.text_name)
    assert_equal("Xanthoparmelia coloradoensis", name.search_name)
    assert_equal("**__Xanthoparmelia coloradoensis__**", name.display_name)
  end

  def test_edit_name_fixing_variety
    login("katrina")
    name = Name.create!(
      text_name: "Pleurotus djamor",
      search_name: "Pleurotus djamor (Fr.) Boedijn var. djamor",
      sort_name: "Pleurotus djamor (Fr.) Boedijn var. djamor",
      display_name: "**__Pleurotus djamor__** (Fr.) Boedijn var. djamor",
      author: "(Fr.) Boedijn var. djamor",
      rank: "Species",
      deprecated: false,
      correct_spelling: nil
    )
    params = {
      id: name.id,
      name: {
        text_name: "Pleurotus djamor var. djamor (Fr.) Boedijn",
        author: "",
        rank: "Variety",
        deprecated: "false"
      }
    }
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    name.reload
    assert_equal("Variety", name.rank)
    assert_equal("Pleurotus djamor var. djamor", name.text_name)
    assert_equal("Pleurotus djamor var. djamor (Fr.) Boedijn", name.search_name)
    assert_equal("(Fr.) Boedijn", name.author)
    # In the bug in the wild, it was failing to create the parents.
    assert(Name.find_by(text_name: "Pleurotus djamor"))
    assert(Name.find_by(text_name: "Pleurotus"))
  end

  def test_edit_name_change_to_group
    login("mary")
    name = Name.create!(
      text_name: "Lepiota echinatae",
      search_name: "Lepiota echinatae Group",
      sort_name: "Lepiota echinatae Group",
      display_name: "**__Lepiota echinatae__** Group",
      author: "Group",
      rank: "Species",
      deprecated: false,
      correct_spelling: nil
    )
    params = {
      id: name.id,
      name: {
        text_name: "Lepiota echinatae",
        author: "Group",
        rank: "Group",
        deprecated: "false"
      }
    }
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    name.reload
    assert_equal("Group", name.rank)
    assert_equal("Lepiota echinatae group", name.text_name)
    assert_equal("Lepiota echinatae group", name.search_name)
    assert_equal("**__Lepiota echinatae__** group", name.display_name)
    assert_equal("", name.author)
  end

  def test_edit_name_screwy_notification_bug
    login("mary")
    name = Name.create!(
      text_name: "Ganoderma applanatum",
      search_name: "Ganoderma applanatum",
      sort_name: "Ganoderma applanatum",
      display_name: "__Ganoderma applanatum__",
      author: "",
      rank: "Species",
      deprecated: true,
      correct_spelling: nil,
      citation: "",
      notes: ""
    )
    Interest.create!(
      target: name,
      user: rolf,
      state: true
    )
    params = {
      id: name.id,
      name: {
        text_name: "Ganoderma applanatum",
        author: "",
        rank: "Species",
        deprecated: "true",
        citation: "",
        notes: "Changed notes."
      }
    }
    put(:update, params: params)
    # was crashing while notifying rolf because new version wasn't saved yet
    assert_flash_success
  end

  # Prove that editing can create multiple ancestors
  def test_edit_name_create_multiple_ancestors
    name        = names(:two_ancestors)
    new_name    = "Neo#{name.text_name.downcase}"
    new_species = new_name.sub(/(\w* \w*).*/, '\1')
    new_genus   = new_name.sub(/(\w*).*/, '\1')
    name_count  = Name.count
    params = {
      id: name.id,
      name: {
        text_name: new_name,
        author: name.author,
        rank: name.rank
      }
    }
    login(name.user.login)
    put(:update, params: params)

    assert_equal(name_count + 2, Name.count)
    assert(Name.exists?(text_name: new_species), "Failed to create new species")
    assert(Name.exists?(text_name: new_genus), "Failed to create new genus")
  end

  def test_edit_and_update_locked_name
    name = names(:stereum_hirsutum)
    name.update(locked: true)
    params = {
      id: name.id,
      name: {
        locked: "0",
        icn_id: 666,
        rank: "Genus",
        deprecated: true,
        text_name: "Foo",
        author: "Bar",
        citation: "new citation",
        notes: "new notes"
      }
    }
    login("rolf")

    get(:edit, params: { id: name.id })
    # Rolf is not an admin, so form should not show locked fields as changeable
    assert_select("input[type=text]#name_icn_id", count: 0)
    assert_select("select#name_rank", count: 0)
    assert_select("select#name_deprecated", count: 0)
    assert_select("input[type=text]#name_text_name", count: 0)
    assert_select("textarea#name_author", count: 0)
    assert_select("input[type=checkbox]#name_misspelling", count: 0)
    assert_select("input[type=text]#name_correct_spelling", count: 0)

    put(:update, params: params)
    name.reload
    # locked attributes should not change
    assert_true(name.locked)
    assert_nil(name.icn_id)
    assert_equal("Species", name.rank)
    assert_false(name.deprecated)
    assert_equal("Stereum hirsutum", name.text_name)
    assert_equal("(Willd.) Pers.", name.author)
    assert_nil(name.correct_spelling_id)
    # unlocked attributes should change
    assert_equal("new citation", name.citation)
    assert_equal("new notes", name.notes)

    make_admin("rolf")
    get(:edit, params: { id: name.id })
    assert_select("input[type=text]#name_icn_id", count: 1)
    assert_select("select#name_rank", count: 1)
    assert_select("select#name_deprecated", count: 1)
    assert_select("input[type=text]#name_text_name", count: 1)
    assert_select("textarea#name_author", count: 1)
    assert_select("input[type=checkbox]#name_misspelling", count: 1)
    assert_select("input[type=text]#name_correct_spelling", count: 1)

    put(:update, params: params)
    name.reload
    assert_equal(params[:name][:icn_id], name.icn_id)
    assert_equal("Foo", name.text_name)
    assert_equal("Bar", name.author)
    assert_equal("Genus", name.rank)
    assert_false(name.locked)
    assert_redirected_to(deprecate_name_synonym_form_path(name.id))
  end

  def test_edit_misspelled_name
    misspelled_name = names(:suilus)
    login("rolf")
    get(:edit, params: { id: misspelled_name.id })
    assert_select("input[type=checkbox]#name_misspelling", count: 1)
    assert_select("input[type=text]#name_correct_spelling", count: 1)
  end

  def test_update_change_text_name_of_ancestor
    name = names(:boletus)
    params = {
      id: name.id,
      name: {
        text_name: "Superboletus",
        author: name.author,
        rank: name.rank
      }
    }
    login(name.user.login)
    put(:update, params: params)

    assert_redirected_to(
      emails_name_change_request_path(name_id: name.id,
                                      new_name_with_icn_id: "Superboletus [#]"),
      "User should be unable to change text_name of Name with dependents"
    )
  end

  def test_update_minor_change_to_ancestor
    name = names(:boletus)
    assert(name.children.present? &&
           name.icn_id.blank? && name.author.blank? && name.citation.blank?,
           "Test needs different fixture: " \
           "Name with a child, and without icn_id, author, or citation")
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        rank: name.rank,
        # adding these should be a minor change
        icn_id: "17175",
        author: "L.",
        citation: "Sp. pl. 2: 1176 (1753)"
      }
    }

    login(name.user.login)
    put(:update, params: params)

    assert_flash_success(
      "User should be able to make minor changes to Name that has offspring"
    )
    assert_no_emails
    name.reload
    assert_equal(params[:name][:icn_id], name.icn_id.to_s)
    assert_equal(params[:name][:author], name.author)
    assert_equal(params[:name][:citation], name.citation)
  end

  def test_update_change_text_name_of_approved_synonym
    approved_synonym = names(:lactarius_alpinus)
    deprecated_name = names(:lactarius_alpigenes)
    login("rolf")
    Naming.create(name: deprecated_name,
                  observation: observations(:minimal_unknown_obs))
    assert(
      !approved_synonym.deprecated &&
        Naming.where(name: approved_synonym).none? &&
        deprecated_name.synonym == approved_synonym.synonym,
      "Test needs different fixture: " \
      "an Approved Name without Namings, with a synonym having Naming(s)"
    )
    changed_name = names(:agaricus_campestris) # can be any other name

    params = {
      id: approved_synonym.id,
      name: {
        text_name: changed_name.text_name,
        author: changed_name.author,
        rank: changed_name.rank,
        deprecated: changed_name.deprecated
      }
    }
    put(:update, params: params)

    assert_redirected_to(
      /#{emails_name_change_request_path}/,
      "User should be unable to change an approved synonym of a Naming"
    )
  end

  def test_update_add_icn_id
    name = names(:stereum_hirsutum)
    rank = name.rank
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: 189_826
      }
    }
    user = name.user
    login(user.login)

    assert_difference("name.versions.count", 1) do
      put(:update, params: params)
    end
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_equal(189_826, name.reload.icn_id)
    assert_no_emails

    assert_equal(rank, Name.ranks.key(name.versions.first.rank),
                 "Rank versioned incorrectly.")
  end

  def test_update_icn_id_unchanged
    name = names(:coprinus_comatus)
    assert(name.icn_id, "Test needs a fixture with an icn_id")
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: name.icn_id,
        notes: "A zillion synonyms and other stuff copied from Index Fungorum"
      }
    }
    user = name.user
    login(user.login)

    assert_difference("name.versions.count", 1) do
      put(:update, params: params)
    end
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
  end

  def test_update_change_icn_id_name_with_dependents
    name = names(:lactarius)
    assert(name.icn_id, "Test needs a fixture with an icn_id")
    assert(name.dependents?, "Test needs a fixture with dependents")
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: name.icn_id + 1,
        notes: name.notes
      }
    }
    user = name.user
    login(user.login)

    put(:update, params: params)
    assert_redirected_to(
      emails_name_change_request_path(
        name_id: name.id,
        new_name_with_icn_id: "#{name.search_name} [##{name.icn_id + 1}]"
      ),
      "Editing id# of Name w/dependents should show Name Change Request form"
    )
  end

  def test_update_icn_id_unregistrable
    name = names(:authored_group)
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: 189_826
      }
    }
    login
    put(:update, params: params)

    assert_flash_error(:name_error_unregistrable.l)
  end

  def test_update_icn_id_non_numeric
    name = names(:stereum_hirsutum)
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: "MB12345"
      }
    }
    default_validates_numericality_of_error_message = "is not a number"
    login
    put(:update, params: params)

    assert_flash_text(/#{default_validates_numericality_of_error_message}/)
  end

  def test_update_icn_id_duplicate
    name = names(:stereum_hirsutum)
    name_with_icn_id = names(:coprinus_comatus)
    assert(name_with_icn_id.icn_id, "Test needs a fixture with an icn_id")
    params = {
      id: name.id,
      name: {
        version: name.version,
        text_name: name.text_name,
        author: name.author,
        sort_name: name.sort_name,
        rank: name.rank,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false"),
        icn_id: name_with_icn_id.icn_id
      }
    }
    login
    put(:update, params: params)

    assert_flash_error(:name_error_icn_id_in_use.l)
  end

  # ----------------------------
  #  Update name -- with merge
  # ----------------------------

  def test_update_name_destructive_merge
    old_name = agaricus_campestrus = names(:agaricus_campestrus)
    new_name = agaricus_campestris = names(:agaricus_campestris)
    new_versions = new_name.versions.size
    old_obs = old_name.namings[0].observation
    new_obs = new_name.namings.
              find { |n| n.observation.name == new_name }.observation

    params = {
      id: old_name.id,
      name: {
        text_name: agaricus_campestris.text_name,
        author: agaricus_campestris.author,
        rank: "Species",
        deprecated: agaricus_campestris.deprecated
      }
    }
    login("rolf")

    # Fails because Rolf isn't in admin mode.
    put(:update, params: params)
    assert_redirected_to(emails_merge_request_path(
                           type: :Name, old_id: old_name.id, new_id: new_name.id
                         ))
    assert(Name.find(old_name.id))
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(2, new_name.namings.size)
    assert_equal(agaricus_campestrus, old_obs.reload.name)
    assert_equal(agaricus_campestris, new_obs.reload.name)

    # Try again as an admin.
    make_admin
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(3, new_name.namings.size)
    assert_equal(agaricus_campestris, old_obs.reload.name)
    assert_equal(agaricus_campestris, new_obs.reload.name)
  end

  def test_update_name_author_merge
    # Names differing only in author
    old_name = names(:amanita_baccata_borealis)
    new_name = names(:amanita_baccata_arora)
    new_author = new_name.author
    new_versions = new_name.versions.size
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: new_name.author,
        rank: "Species",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
    assert_equal(new_author, new_name.reload.author)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
  end

  # Prove that user can remove author if there's a match to desired Name,
  # and the merge is non-destructive
  def test_update_name_remove_author_nondestructive_merge
    old_name   = names(:mergeable_epithet_authored)
    new_name   = names(:mergeable_epithet_unauthored)
    name_count = Name.count
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: "",
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(old_name.user.login)
    put(:update, params: params)

    assert_redirected_to(name_path(new_name.id))
    assert_flash_success
    assert_empty(new_name.reload.author)
    assert_no_emails
    assert_equal(name_count - 1, Name.count)
    assert_not(Name.exists?(old_name.id))
  end

  # Prove that user can add author if there's a match to desired Name,
  # and the merge is non-destructive
  def test_update_name_add_author_nondestructive_merge
    old_name   = names(:mergeable_epithet_unauthored)
    new_name   = names(:mergeable_epithet_authored)
    new_author = new_name.author
    name_count = Name.count
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: new_author,
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(old_name.user.login)
    put(:update, params: params)

    assert_redirected_to(name_path(new_name.id))
    assert_flash_success
    assert_equal(new_author, new_name.reload.author)
    assert_no_emails
    assert_equal(name_count - 1, Name.count)
    assert_not(Name.exists?(old_name.id))
  end

  def test_update_name_remove_author_destructive_merge
    old_name = names(:authored_with_naming)
    new_name = names(:unauthored_with_naming)
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: "",
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }

    login("rolf")
    put(:update, params: params)
    assert_redirected_to(emails_merge_request_path(
                           type: :Name, old_id: old_name.id, new_id: new_name.id
                         ))

    # Try again as an admin.
    make_admin
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
  end

  def test_update_name_merge_author_with_notes
    bad_name = names(:hygrocybe_russocoriacea_bad_author)
    bad_id = bad_name.id
    bad_notes = bad_name.notes
    good_name = names(:hygrocybe_russocoriacea_good_author)
    good_id = good_name.id
    good_author = good_name.author
    params = {
      id: bad_name.id,
      name: {
        text_name: bad_name.text_name,
        author: good_author,
        notes: bad_notes,
        rank: "Species",
        deprecated: (bad_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    make_admin
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_id))
    assert_no_emails
    assert_not(Name.exists?(bad_id))
    reload_name = Name.find(good_id)
    assert(reload_name)
    assert_equal(good_author, reload_name.author)
    assert_match(/#{bad_notes}\Z/, reload_name.notes,
                 "old_name notes should be appended to target name's notes")
  end

  # Make sure misspelling gets transferred when new name merges away.
  def test_update_name_misspelling_merge
    old_name = names(:suilus)
    wrong_author_name = names(:suillus_by_white)
    new_name = names(:suillus)
    old_correct_spelling_id = old_name.correct_spelling_id
    params = {
      id: wrong_author_name.id,
      name: {
        text_name: wrong_author_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        deprecated: (wrong_author_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(wrong_author_name.id))
    assert_not_equal(old_correct_spelling_id,
                     old_name.reload.correct_spelling_id)
    assert_equal(old_name.correct_spelling, new_name)
  end

  # Test that merged names end up as not deprecated if the
  # new name is not deprecated.
  def test_update_name_deprecated_merge
    old_name = names(:lactarius_alpigenes)
    new_name = names(:lactarius_alpinus)
    new_author = new_name.author
    new_versions = new_name.versions.size
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: "Species",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
    assert(new_name.reload)
    assert_not(new_name.deprecated)
    assert_equal(new_author, new_name.author)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
  end

  # Test that merged name doesn't change deprecated status
  # unless the user explicitly changes status in form.
  def test_update_name_deprecated2_merge
    good_name = names(:lactarius_alpinus)
    bad_name1 = names(:lactarius_alpigenes)
    bad_name2 = names(:lactarius_kuehneri)
    bad_name3 = names(:lactarius_subalpinus)
    bad_name4 = names(:pluteus_petasatus_approved)
    good_text_name = good_name.text_name
    good_author = good_name.author

    # First: merge deprecated into accepted, no change.
    assert_not(good_name.deprecated)
    assert(bad_name1.deprecated)
    params = {
      id: bad_name1.id,
      name: {
        text_name: good_name.text_name,
        author: good_name.author,
        rank: "Species",
        deprecated: "false"
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_name.id))
    assert_no_emails
    assert_not(Name.exists?(bad_name1.id))
    assert(good_name.reload)
    assert_not(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(1, good_name.version)
    assert_equal(1, good_name.versions.size)

    # Second: merge accepted into deprecated, no change.
    good_name.change_deprecated(true)
    bad_name2.change_deprecated(false)
    good_name.save
    bad_name2.save
    assert_equal(2, good_name.version)
    assert_equal(2, good_name.versions.size)

    assert(good_name.deprecated)
    assert_not(bad_name2.deprecated)
    params[:id] = bad_name2.id
    params[:name][:deprecated] = "true"
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_name.id))
    assert_no_emails
    assert_not(Name.exists?(bad_name2.id))
    assert(good_name.reload)
    assert(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(2, good_name.version)
    assert_equal(2, good_name.versions.size)

    # Third: merge deprecated into deprecated, but change to accepted.
    assert(good_name.deprecated)
    assert(bad_name3.deprecated)
    params[:id] = bad_name3.id
    params[:name][:deprecated] = "false"
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_name.id))
    assert_no_emails
    assert_not(Name.exists?(bad_name3.id))
    assert(good_name.reload)
    assert_not(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(3, good_name.version)
    assert_equal(3, good_name.versions.size)

    # Fourth: merge accepted into accepted, but change to deprecated.
    assert_not(good_name.deprecated)
    assert_not(bad_name4.deprecated)
    params[:id] = bad_name4.id
    params[:name][:deprecated] = "true"
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(good_name.id))
    assert_no_emails
    assert_not(Name.exists?(bad_name4.id))
    assert(good_name.reload)
    assert(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(4, good_name.version)
    assert_equal(4, good_name.versions.size)
  end

  # Test merge two names where the new name has description notes.
  def test_update_name_merge_no_notes_into_description_notes
    old_name = names(:mergeable_no_notes)
    new_name = names(:mergeable_description_notes)
    notes = new_name.description.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        citation: "",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
    assert_equal(notes, new_name.description.notes)
  end

  # Test merge two names where the old name had notes.
  def test_update_name_merge_matching_notes2
    old_name = names(:russula_brevipes_author_notes)
    new_name = names(:conocybe_filaris)
    old_citation = old_name.citation
    old_notes = old_name.notes
    old_desc = old_name.description.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: "",
        rank: old_name.rank,
        citation: old_name.citation,
        notes: old_name.notes,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
    assert_equal("", new_name.author) # user explicitly set author to ""
    assert_equal(old_citation, new_name.citation)
    assert_match(/#{old_notes}\Z/, new_name.notes,
                 "old_name notes should be appended to target name's notes")
    assert_not_nil(new_name.description)
    assert_equal(old_desc, new_name.description.notes)
  end

  def test_update_name_merged_notes_include_notes_from_both_names
    old_name = names(:hygrocybe_russocoriacea_bad_author) # has notes
    new_name = names(:russula_brevipes_author_notes)
    original_notes = new_name.notes
    old_name_notes = old_name.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        citation: new_name.citation,
        notes: old_name.notes,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_match(original_notes, new_name.reload.notes)
    assert_match(old_name_notes, new_name.notes)
  end

  # Test merging two names, only one with observations.  Should work either
  # direction, but always keeping the name with observations.
  def test_update_name_merge_one_with_observations
    old_name = names(:mergeable_no_notes) # mergeable, ergo no observation
    assert(old_name.observations.none?, "Test needs a different fixture.")
    new_name = names(:coprinus_comatus) # has observations
    assert(new_name.observations.any?, "Test needs a different fixture.")

    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: old_name.rank,
        citation: "",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
  end

  def test_update_name_merge_one_with_observations_other_direction
    old_name = names(:coprinus_comatus) # has observations
    assert(old_name.observations.any?, "Test needs a different fixture.")
    new_name = names(:mergeable_no_notes) # mergeable, ergo no observations
    assert(new_name.observations.none?, "Test needs a different fixture.")

    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: old_name.rank,
        citation: "",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(old_name.id))
    assert_no_emails
    assert(old_name.reload)
    assert_not(Name.exists?(new_name.id))
  end

  # Test merge two names that both start with notes.
  def test_update_name_merge_both_notes
    old_name = names(:mergeable_description_notes)
    new_name = names(:mergeable_second_description_notes)
    old_notes = old_name.description.notes
    new_notes = new_name.description.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        deprecated: (new_name.deprecated ? "true" : "false"),
        citation: ""
      }
    }
    login("rolf")
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
    assert_equal(new_notes, new_name.description.notes)
    # Make sure old notes are still around.
    other_desc = (new_name.descriptions - [new_name.description]).first
    assert_equal(old_notes, other_desc.notes)
  end

  def test_edit_name_both_with_notes_and_namings
    old_name = names(:agaricus_campestros)
    new_name = names(:agaricus_campestras)
    new_versions = new_name.versions.size
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: old_name.author,
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }

    # Fails normally.
    login("rolf")
    put(:update, params: params)
    assert_redirected_to(emails_merge_request_path(
                           type: :Name, old_id: old_name.id, new_id: new_name.id
                         ))
    assert(old_name.reload)
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(1, new_name.namings.size)
    assert_equal(1, old_name.namings.size)
    assert_not_equal(new_name.namings[0], old_name.namings[0])

    # Try again in admin mode.
    make_admin
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(new_name.id))
    assert_no_emails
    assert_raises(ActiveRecord::RecordNotFound) do
      assert(old_name.reload)
    end
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(2, new_name.namings.size)
  end

  # Prove that name_tracker is moved to new_name
  # when old_name with notication is merged to new_name
  def test_update_name_merge_with_name_tracker
    note = name_trackers(:no_observation_name_tracker)
    old_name = note.name
    new_name = names(:fungi)
    login(old_name.user.name)
    make_admin(old_name.user.login)
    change_old_name_to_new_name_params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        rank: "Genus",
        deprecated: "false"
      }
    }

    put(:update, params: change_old_name_to_new_name_params)
    note.reload

    assert_equal(new_name.id, note.name_id,
                 "Name Tracker was not redirected to target of Name merger")
  end

  # Test that misspellings are handle right when merging.
  def test_update_name_merge_with_misspellings
    login("rolf")
    name1 = names(:lactarius_alpinus)
    name2 = names(:lactarius_alpigenes)
    name3 = names(:lactarius_kuehneri)
    name4 = names(:lactarius_subalpinus)

    # First: merge Y into X, where Y is misspelling of X
    name2.correct_spelling = name1
    name2.change_deprecated(true)
    name2.save
    assert_not(name1.correct_spelling)
    assert_not(name1.deprecated)
    assert(name2.correct_spelling == name1)
    assert(name2.deprecated)
    params = {
      id: name2.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: "Species",
        deprecated: "true"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name1.id))
    assert_no_emails
    assert_not(Name.exists?(name2.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert_not(name1.deprecated)

    # Second: merge Y into X, where X is misspelling of Y
    name1.correct_spelling = name3
    name1.change_deprecated(true)
    name1.save
    name3.correct_spelling = nil
    name3.change_deprecated(false)
    name3.save
    assert(name1.correct_spelling == name3)
    assert(name1.deprecated)
    assert_not(name3.correct_spelling)
    assert_not(name3.deprecated)
    params = {
      id: name3.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: "Species",
        deprecated: "false"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name1.id))
    assert_no_emails
    assert_not(Name.exists?(name3.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert(name1.deprecated)

    # Third: merge Y into X, where X is misspelling of Z
    name1.correct_spelling = Name.first
    name1.change_deprecated(true)
    name1.save
    name4.correct_spelling = nil
    name4.change_deprecated(false)
    name4.save
    assert(name1.correct_spelling)
    assert(name1.correct_spelling != name4)
    assert(name1.deprecated)
    assert_not(name4.correct_spelling)
    assert_not(name4.deprecated)
    params = {
      id: name4.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: "Species",
        deprecated: "false"
      }
    }
    put(:update, params: params)
    assert_flash_success
    assert_redirected_to(name_path(name1.id))
    assert_no_emails
    assert_not(Name.exists?(name4.id))
    assert(name1.reload)
    assert(name1.correct_spelling == Name.first)
    assert(name1.deprecated)
  end

  # Found this in the wild, it seems to have been fixed already, though...
  def test_update_name_merge_authored_misspelt_into_unauthored_correctly_spelled
    login("rolf")

    name2 = Name.create!(
      text_name: "Russula sect. Compactae",
      search_name: "Russula sect. Compactae",
      sort_name: "Russula sect. Compactae",
      display_name: "**__Russula__** sect. **__Compactae__**",
      author: "",
      rank: "Section",
      deprecated: false,
      correct_spelling: nil
    )
    name1 = Name.create!(
      text_name: "Russula sect. Compactae",
      search_name: "Russula sect. Compactae Fr.",
      sort_name: "Russula sect. Compactae Fr.",
      display_name: "__Russula__ sect. __Compactae__ Fr.",
      author: "Fr.",
      rank: "Section",
      deprecated: true,
      correct_spelling: name2
    )
    params = {
      id: name2.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: "Section",
        deprecated: "false"
      }
    }
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name1.id))
    assert_no_emails
    assert_not(Name.exists?(name2.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert(name1.deprecated)
    assert_equal("Russula sect. Compactae", name1.text_name)
    assert_equal("Fr.", name1.author)
  end

  # Another one found in the wild, probably already fixed.
  def test_update_name_merge_authored_with_old_style_unauthored
    login("rolf")
    # Obsolete intrageneric Name, "Genus" with rank & author in the author
    # field. (NameController no longer allows this.)
    old_style_name = Name.create!(
      text_name: "Amanita",
      search_name: "Amanita (sect. Vaginatae)",
      sort_name: "Amanita  (sect. Vaginatae)",
      display_name: "**__Amanita__** (sect. Vaginatae)",
      author: "(sect. Vaginatae)",
      rank: "Genus",
      deprecated: false,
      correct_spelling: nil
    )
    # New style. Uses correct rank, and puts rank text in text_name
    new_style_name = Name.create!(
      text_name: "Amanita sect. Vaginatae",
      search_name: "Amanita sect. Vaginatae (Fr.) Quél.",
      sort_name: "Amanita sect. Vaginatae  (Fr.)   Quél.",
      display_name: "**__Amanita__** sect. **__Vaginatae__** (Fr.) Quél.",
      author: "(Fr.) Quél.",
      rank: "Section",
      deprecated: false,
      correct_spelling: nil
    )
    params = {
      id: old_style_name.id,
      name: {
        text_name: new_style_name.text_name,
        author: new_style_name.author,
        rank: new_style_name.rank,
        deprecated: "false"
      }
    }

    make_admin(old_style_name.user.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(new_style_name.id))
    assert_no_emails
    assert_not(Name.exists?(old_style_name.id))
    assert(new_style_name.reload)
    assert_not(new_style_name.correct_spelling)
    assert_not(new_style_name.deprecated)
    assert_equal("Amanita sect. Vaginatae", new_style_name.text_name)
    assert_equal("(Fr.) Quél.", new_style_name.author)
  end

  # Another one found in the wild, probably already fixed.
  def test_update_name_merge_authored_with_old_style_deprecated
    login("rolf")
    syn = Synonym.create
    name1 = Name.create!(
      text_name: "Cortinarius subg. Sericeocybe",
      search_name: "Cortinarius subg. Sericeocybe",
      sort_name: "Cortinarius subg. Sericeocybe",
      display_name: "**__Cortinarius__** subg. **__Sericeocybe__**",
      author: "",
      rank: "Subgenus",
      deprecated: false,
      correct_spelling: nil,
      synonym: syn
    )
    # The old way to create an intrageneric Name, using the author field
    name2 = Name.create!(
      text_name: "Cortinarius",
      search_name: "Cortinarius (sub Genus Sericeocybe)",
      sort_name: "Cortinarius (sub Genus Sericeocybe)",
      display_name: "__Cortinarius__ (sub Genus Sericeocybe)",
      author: "(sub Genus Sericeocybe)",
      rank: "Genus",
      deprecated: true,
      correct_spelling: nil,
      synonym: syn
    )
    params = {
      id: name2.id,
      name: {
        text_name: "Cortinarius subg. Sericeocybe",
        author: "",
        rank: "Subgenus",
        deprecated: "false"
      }
    }
    make_admin(name1.user.login)
    put(:update, params: params)

    assert_flash_success
    assert_redirected_to(name_path(name1.id))
    assert_no_emails
    assert_not(Name.exists?(name2.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert_not(name1.deprecated)
    assert_equal("Cortinarius subg. Sericeocybe", name1.text_name)
    assert_equal("", name1.author)
  end

  # Merge, trying to change only identifier of surviving name
  def test_update_name_merge_retain_identifier
    edited_name = names(:stereum_hirsutum)
    surviving_name = names(:coprinus_comatus)
    assert(old_identifier = surviving_name.icn_id)

    params = {
      id: edited_name.id,
      name: {
        icn_id: old_identifier + 1_111_111,
        text_name: surviving_name.text_name,
        author: surviving_name.author,
        rank: surviving_name.rank,
        deprecated: (surviving_name.deprecated ? "true" : "false")
      }
    }

    login("rolf")
    assert_no_difference("surviving_name.version") do
      put(:update, params: params)
      surviving_name.reload
    end

    assert_flash_success
    assert_redirected_to(name_path(surviving_name.id))
    assert_email_generated # email admin re icn_id conflict
    assert_not(Name.exists?(edited_name.id))
    assert_equal(
      old_identifier, surviving_name.reload.icn_id,
      "Merge should retain icn_id if it exists"
    )
  end

  def test_update_name_merge_add_identifier
    edited_name = names(:amanita_boudieri_var_beillei)
    survivor = names(:amanita_boudieri)
    assert_nil(edited_name.icn_id, "Test needs fixtures without icn_id")
    assert_nil(survivor.icn_id, "Test needs fixtures without icn_id")

    edited_name.log("create edited_name log")

    destroyed_real_search_name = edited_name.real_search_name
    destroyed_display_name = edited_name.display_name

    params = {
      id: edited_name.id,
      name: {
        icn_id: 208_785,
        text_name: survivor.text_name,
        author: edited_name.author,
        rank: survivor.rank,
        deprecated: (survivor.deprecated ? "true" : "false")
      }
    }
    login("rolf")

    assert_difference("survivor.versions.count", 1) do
      put(:update, params: params)
    end

    assert_redirected_to(name_path(survivor.id))

    expect = "Successfully merged name #{destroyed_real_search_name} " \
             "into #{survivor.real_search_name}"
    assert_flash_text(/#{expect}/, "Merger success flash is incorrect")

    assert_no_emails
    assert_not(Name.exists?(edited_name.id))
    assert_equal(208_785, survivor.reload.icn_id)

    log = RssLog.last.parse_log
    assert_equal(:log_orphan, log[0][0])
    assert_equal({ title: destroyed_display_name }, log[0][1])
    assert_equal(:log_name_merged, log[1][0])
    assert_equal({ this: destroyed_display_name,
                   that: survivor.display_name,
                   user: "rolf" }, log[1][1])
  end

  def test_update_name_reverse_merge_add_identifier
    edited_name = names(:coprinus_comatus)
    merged_name = names(:stereum_hirsutum) # has empty icn_id
    assert_nil(merged_name.icn_id, "Test needs a fixture without icn_id")

    params = {
      id: edited_name.id,
      name: {
        icn_id: 189_826,
        text_name: merged_name.text_name,
        author: merged_name.author,
        rank: merged_name.rank,
        deprecated: (merged_name.deprecated ? "true" : "false")
      }
    }

    login("rolf")
    # merged_name is merged into edited_name because former has name proposals
    # and the latter does not
    assert_difference("edited_name.version") do
      put(:update, params: params)
      edited_name.reload
    end

    assert_flash_success
    assert_redirected_to(name_path(edited_name.id))
    assert_no_emails
    assert_not(Name.exists?(merged_name.id))
    assert_equal(189_826, edited_name.reload.icn_id)
  end

  def test_update_name_multiple_matches
    old_name = names(:agaricus_campestrus)
    new_name = names(:agaricus_campestris)
    duplicate = new_name.dup
    duplicate.save(validate: false)

    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        deprecated: new_name.deprecated
      }
    }
    login("rolf")
    make_admin

    assert_no_difference("Name.count") do
      put(:update, params: params)
    end
    assert_response(:success) # form reloaded
    assert_flash_error(:edit_name_multiple_names_match.l)
  end

  def test_name_guessing
    # Not all the genera actually have records in our test database.
    User.current = rolf
    @controller.instance_variable_set(:@user, rolf)
    Name.create_needed_names("Agaricus")
    Name.create_needed_names("Pluteus")
    Name.create_needed_names("Coprinus comatus subsp. bogus var. varietus")

    assert_name_suggestions("Agricus")
    assert_name_suggestions("Ptligera")
    assert_name_suggestions(" plutues _petastus  ")
    assert_name_suggestions("Coprinis comatis")
    assert_name_suggestions("Coprinis comatis blah. boggle")
    assert_name_suggestions("Coprinis comatis blah. boggle var. varitus")
  end

  def assert_name_suggestions(str)
    results = Name.suggest_alternate_spellings(str)
    assert(results.any?,
           "Couldn't suggest alternate spellings for #{str.inspect}.")
  end
end
