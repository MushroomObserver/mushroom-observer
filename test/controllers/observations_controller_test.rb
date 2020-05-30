# frozen_string_literal: true

# TODO: NIMMO Split off new controller tests into their own test files!
# Especially search, account, comment, rss_logs
require "test_helper"

class ObservationsControllerTest < FunctionalTestCase
  def modified_generic_params(params, user)
    params[:observation] = sample_obs_fields.merge(params[:observation] || {})
    params[:vote] = { value: "3" }.merge(params[:vote] || {})
    params[:collection_number] =
      default_collection_number_fields.merge(params[:collection_number] || {})
    params[:herbarium_record] =
      default_herbarium_record_fields.merge(params[:herbarium_record] || {})
    params[:username] = user.login
    params
  end

  def sample_obs_fields
    { place_name: "Right Here, Massachusetts, USA",
      lat: "",
      long: "",
      alt: "",
      "when(1i)" => "2007",
      "when(2i)" => "10",
      "when(3i)" => "31",
      specimen: "0",
      thumb_image_id: "0" }
  end

  def default_collection_number_fields
    { name: "", number: "" }
  end

  def default_herbarium_record_fields
    { herbarium_name: "", herbarium_id: "" }
  end

  def location_exists_or_place_name_blank(params)
    Location.find_by(name: params[:observation][:place_name]) ||
      Location.is_unknown?(params[:observation][:place_name]) ||
      params[:observation][:place_name].blank?
  end

  # Test constructing observations in various ways (with minimal namings)
  def generic_construct_observation(params, o_num, g_num, n_num, user = rolf)
    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    score   = user.reload.contribution
    params  = modified_generic_params(params, user)

    post_requires_login(:new, params)

    begin
      if o_num.zero?
        assert_response(:success)
      elsif location_exists_or_place_name_blank(params)
        # assert_redirected_to(action: :show)
        assert_response(:redirect)
        assert_match(%r{/test.host/\d+\Z}, @response.redirect_url)
      else
        assert_redirected_to(%r{/locations/new})
      end
    rescue MiniTest::Assertion => e
      flash = get_last_flash.to_s
      flash.sub!(/^(\d)/, "")
      message = "#{e}\n" \
                "Flash messages: (level #{Regexp.last_match(1)})\n" \
                "< #{flash} >\n"
      flunk(message)
    end
    assert_equal(o_count + o_num, Observation.count, "Wrong Observation count")
    assert_equal(g_count + g_num, Naming.count, "Wrong Naming count")
    assert_equal(n_count + n_num, Name.count, "Wrong Name count")
    assert_equal(score + o_num + 2 * g_num + 10 * n_num,
                 user.reload.contribution,
                 "Wrong User score")
    return unless o_num == 1

    assert_not_equal(
      0,
      @controller.instance_variable_get("@observation").thumb_image_id,
      "Wrong image id"
    )
  end

  def test_create_observation_with_unrecognized_name
    text_name = "Elfin saddle"
    params = { name: { name: text_name },
               user: rolf,
               where: locations.first.name }
    post_requires_login(:new, params)

    assert_select("div[id='name_messages']",
                  /MO does not recognize the name.*#{text_name}/)
  end

  ##############################################################################

  # ----------------------------
  #  General tests.
  # ----------------------------

  def test_show_observation_noteless_image
    obs = observations(:peltigera_rolf_obs)
    img = images(:rolf_profile_image)
    assert_nil(img.notes)
    assert(obs.images.member?(img))
    get_with_dump(:show, id: obs.id)
  end

  def test_show_observation_noteful_image
    obs = observations(:detailed_unknown_obs)
    get_with_dump(:show, id: obs.id)
  end

  def test_show_observation_change_thumbnail_size
    user = users(:small_thumbnail_user)
    login(user.name)
    get(:show,
        params: { set_thumbnail_size: :thumbnail })
    user.reload
    assert_equal(:thumbnail, user.thumbnail_size)
  end

  def test_show_observation_hidden_gps
    obs = observations(:unknown_with_lat_long)
    get(:show, id: obs.id)
    assert_match(/34.1622|118.3521/, @response.body)

    obs.update(gps_hidden: true)
    get(:show, id: obs.id)
    assert_no_match(/34.1622|118.3521/, @response.body)

    login("mary")
    get(:show, id: obs.id)
    assert_match(/34.1622|118.3521/, @response.body)
    assert_match(:show_observation_gps_hidden.t, @response.body)
  end

  def test_show_obs
    obs = observations(:fungi_obs)
    get(:show,
        params: { id: obs.id })
    assert_redirected_to(action: :show, id: obs.id)
  end

  def test_page_loads
    get_with_dump(:index)
    assert_template(
      :index,
      partial: :_rss_log
    )
    assert_link_in_html(
      :app_intro.t,
      controller: :observations,
      action: :intro
    )
    assert_link_in_html(
      :app_create_account.t,
      controller: :account,
      action: :signup
    )

    get_with_dump(:ask_webmaster_question)
    assert_template(:ask_webmaster_question)
    assert_form_action(action: :ask_webmaster_question)

    get_with_dump(:how_to_help)
    assert_template(:how_to_help)

    get_with_dump(:how_to_use)
    assert_template(:how_to_use)

    get_with_dump(:intro)
    assert_template(:intro)

    get(:search_bar_help)
    assert_response(:success)

    get_with_dump(:index)
    assert_template(
      :index,
      partial: :_rss_log
    )

    # Test again, this time specifying page number via an observation id.
    get(:index,
        params: { id: observations(:agaricus_campestris_obs).id })
    assert_template(
      :index,
      partial: :_rss_log
    )

    get(:observations_for_project,
        params: { id: projects(:bolete_project).id })
    assert_template(
      :index,
      partial: :_rss_log
    )

    # TODO: NIMMO move to rss_logs_controller_test
    get_with_dump(:list_rss_logs)
    assert_template(
      :index,
      partial: :_rss_log
    )

    get_with_dump(:news)
    assert_template(:news)

    get_with_dump(:observations_by_name)
    assert_template(
      :index,
      partial: :_rss_log
    )

    get(:observations_of_name,
        params: { name: names(:boletus_edulis).text_name })
    assert_template(
      :index,
      partial: :_rss_log
    )

    # TODO: NIMMO move to rss_logs_controller_test
    get_with_dump(:rss)
    assert_template(:rss)

    get_with_dump(:show, id: rss_logs(:observation_rss_log).id)
    assert_template(:show)

    # TODO: NIMMO move to users_controller_test
    get_with_dump(:users_by_contribution)
    assert_template(:users_by_contribution)

    get_with_dump(:show, id: rolf.id)
    assert_template(:show)

    # TODO: NIMMO move to info_controller_test
    get_with_dump(:show_site_stats)
    assert_template(:show_site_stats)

    get_with_dump(:observations_by_user, id: rolf.id)
    assert_template(
      :index,
      partial: :_rss_log
    )

    # get_with_dump(:login)
    # assert_redirected_to(controller: :account, action: :login)

    get_with_dump(:textile)
    assert_template(:textile_sandbox)

    get_with_dump(:textile_sandbox)
    assert_template(:textile_sandbox)
  end

  def test_rss_with_article_in_feed
    login("rolf")
    article = Article.create!(title: "Really _Neat_ Feature!",
                              body: "Does stuff.")
    assert_equal("Really Neat Feature!", article.text_name)
    get(:rss)
  end

  def test_page_load_user_by_contribution
    get_with_dump(:users_by_contribution)
    assert_template(:users_by_contribution)
  end

  def test_observations_by_unknown_user
    get(:observations_by_user, params: { id: 1e6 })
    assert_redirected_to(action: :index_user)
  end

  def test_altering_types_shown_by_rss_log_index
    # Show none.
    post(:index_rss_log)
    assert_template(:index)

    # Show one.
    post(:index_rss_log,
         params: { show_observations: observations(:minimal_unknown_obs).to_s })
    assert_template(:index)

    # Show all.
    params = {}
    RssLog.all_types.each { |type| params["show_#{type}"] = "1" }
    post(:index_rss_log, params: params)
    assert_template(
      :index,
      partial: rss_logs(:observation_rss_log).id
    )
  end

  def test_get_index_rss_log
    # With params[:type], it should display only that type
    expect = rss_logs(:glossary_term_rss_log)
    get(:index_rss_log,
        params: { type: :glossary_term })
    assert_match(/#{expect.glossary_term.name}/, css_select(".log-what").text)
    assert_no_match(/#{rss_logs(:observation_rss_log).observation.name}/,
                    css_select(".log-what").text)

    # Without params[:type], it should display all logs
    get(:index_rss_log)
    assert_match(/#{expect.glossary_term.name}/, css_select(".log-what").text)
    assert_match(/#{rss_logs(:observation_rss_log).observation.name.text_name}/,
                 css_select(".log-what").text)
  end

  def test_user_default_rss_log
    # Prove that MO offers to make non-default log the user's default.
    login("rolf")
    get(:index_rss_log, params: { type: :glossary_term })
    link_text = @controller.instance_variable_get("@links").flatten.first
    assert_equal(:rss_make_default.l, link_text)

    # Prove that user can change his default rss log type.
    get(:index_rss_log, params: { type: :glossary_term, make_default: 1 })
    assert_equal("glossary_term", rolf.reload.default_rss_type)
  end

  # Prove that user content_filter works on rss_log
  def test_rss_log_with_content_filter
    login(users(:vouchered_only_user).name)
    get(:index_rss_log, params: { type: :observation })
    results = @controller.instance_variable_get("@objects")

    assert(results.exclude?(rss_logs(:imged_unvouchered_obs_rss_log)))
    assert(results.include?(rss_logs(:observation_rss_log)))
  end

  def test_next_and_prev_rss_log
    # First 2 log entries
    logs = RssLog.order(updated_at: :desc).limit(2)

    get(:next_rss_log, params: { id: logs.first })
    # assert_redirected_to does not work here because #next redirects to a url
    # which includes a query after the id, but assert_redirected_to treats
    # the query as part of the id.
    assert_response(:redirect)
    assert_match(%r{/show_rss_log/#{logs.second.id}},
                 @response.header["Location"], "Redirected to wrong page")

    get(:prev_rss_log, params: { id: logs.second })
    assert_response(:redirect)
    assert_match(%r{/show_rss_log/#{logs.first.id}},
                 @response.header["Location"], "Redirected to wrong page")
  end

  def test_prev_and_next_observation
    # Uses default observation query
    o_chron = Observation.order(:created_at)
    get(:show_next, params: { id: o_chron.fourth.id })
    assert_redirected_to(action: :show, id: o_chron.third.id,
                         params: @controller.query_params(QueryRecord.last))

    get(:show_prev, params: { id: o_chron.fourth.id })
    assert_redirected_to(action: :show, id: o_chron.fifth.id,
                         params: @controller.query_params(QueryRecord.last))
  end

  def test_prev_and_next_observation_with_fancy_query
    n1 = names(:agaricus_campestras)
    n2 = names(:agaricus_campestris)
    n3 = names(:agaricus_campestros)
    n4 = names(:agaricus_campestrus)

    n2.transfer_synonym(n1)
    n2.transfer_synonym(n3)
    n2.transfer_synonym(n4)
    n1.correct_spelling = n2
    n1.save_without_our_callbacks

    o1 = n1.observations.first
    o2 = n2.observations.first
    o3 = n3.observations.first
    o4 = n4.observations.first

    # When requesting non-synonym observations of n2, it should include n1,
    # since an observation of n1 was clearly intended to be an observation of
    # n2.
    query = Query.lookup_and_save(:Observation, :all,
                                  names: n2.id,
                                  include_synonyms: false,
                                  by: :name)
    assert_equal(2, query.num_results)

    # Likewise, when requesting *synonym* observations, neither n1 nor n2
    # should be included.
    query = Query.lookup_and_save(:Observation, :all,
                                  names: n2.id,
                                  include_synonyms: true,
                                  exclude_original_names: true,
                                  by: :name)
    assert_equal(2, query.num_results)

    # But for our prev/next test, lets do the all-inclusive query.
    query = Query.lookup_and_save(:Observation, :all,
                                  names: n2.id,
                                  include_synonyms: true,
                                  by: :name)
    assert_equal(4, query.num_results)
    qp = @controller.query_params(query)

    o_id = observations(:minimal_unknown_obs).id

    get(:show_next, params: qp.merge(id: o_id))
    assert_redirected_to(action: :show, id: o_id, params: qp)
    assert_flash_text(/can.*t find.*results.*index/i)
    get(:show_next, params: qp.merge(id: o1.id))
    assert_redirected_to(action: :show, id: o2.id, params: qp)
    get(:show_next, params: qp.merge(id: o2.id))
    assert_redirected_to(action: :show, id: o3.id, params: qp)
    get(:show_next, params: qp.merge(id: o3.id))
    assert_redirected_to(action: :show, id: o4.id, params: qp)
    get(:show_next, params: qp.merge(id: o4.id))
    assert_redirected_to(action: :show, id: o4.id, params: qp)
    assert_flash_text(/no more/i)

    get(:show_prev, params: qp.merge(id: o4.id))
    assert_redirected_to(action: :show, id: o3.id, params: qp)
    get(:show_prev, params: qp.merge(id: o3.id))
    assert_redirected_to(action: :show, id: o2.id, params: qp)
    get(:show_prev, params: qp.merge(id: o2.id))
    assert_redirected_to(action: :show, id: o1.id, params: qp)
    get(:show_prev, params: qp.merge(id: o1.id))
    assert_redirected_to(action: :show, id: o1.id, params: qp)
    assert_flash_text(/no more/i)
    get(:show_prev, params: qp.merge(id: o_id))
    assert_redirected_to(action: :show, id: o_id, params: qp)
    assert_flash_text(/can.*t find.*results.*index/i)
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Observation, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    get(:advanced_search, params: @controller.query_params(query))
    assert_template(:index)
  end

  def test_advanced_search_2
    get(:advanced_search,
        params: { name: "Agaricus", location: "California" })
    assert_response(:success)
    results = @controller.instance_variable_get("@objects")
    assert_equal(4, results.length)
  end

  def test_advanced_search_3
    # Fail to include notes.
    get(:advanced_search,
        params: {
          name: "Fungi",
          location: "String in notes"
        })
    assert_response(:success)
    results = @controller.instance_variable_get("@objects")
    assert_equal(0, results.length)

    # Include notes, but notes don't have string yet!
    get(
      :advanced_search,
      params: {
        name: "Fungi",
        location: '"String in notes"',
        search_location_notes: 1
      }
    )
    assert_response(:success)
    results = @controller.instance_variable_get("@objects")
    assert_equal(0, results.length)

    # Add string to notes, make sure it is actually added.
    login("rolf")
    loc = locations(:burbank)
    loc.notes = "blah blah blahString in notesblah blah blah"
    loc.save
    loc.reload
    assert(loc.notes.to_s.include?("String in notes"))

    # Forget to include notes again.
    get(:advanced_search,
        params: {
          name: "Fungi",
          location: "String in notes"
        })
    assert_response(:success)
    results = @controller.instance_variable_get("@objects")
    assert_equal(0, results.length)

    # Now it should finally find the three unknowns at Burbank because Burbank
    # has the magic string in its notes, and we're looking for it.
    get(:advanced_search,
        params: {
          name: "Fungi",
          location: '"String in notes"',
          search_location_notes: 1
        })
    assert_response(:success)
    results = @controller.instance_variable_get("@objects")
    assert_equal(3, results.length)
  end

  def test_advanced_search_content_filters
    # Make sure all the right buttons and fields are present.
    get(:advanced_search_form)
    assert_select("input[type=radio]#content_filter_has_images_yes")
    assert_select("input[type=radio]#content_filter_has_images_no")
    assert_select("input[type=radio]#content_filter_has_images_")
    assert_select("input[type=radio]#content_filter_has_specimen_yes")
    assert_select("input[type=radio]#content_filter_has_specimen_no")
    assert_select("input[type=radio]#content_filter_has_specimen_")
    assert_select("input[type=radio]#content_filter_lichen_yes")
    assert_select("input[type=radio]#content_filter_lichen_no")
    assert_select("input[type=radio]#content_filter_lichen_")
    assert_select("input[type=text]#content_filter_region")
    assert_select("input[type=text]#content_filter_clade")

    params = {
      search: {
        model: "observation",
        user: "rolf"
      },
      content_filter_has_images: "",
      content_filter_has_specimen: "yes",
      content_filter_lichen: "no",
      content_filter_region: "California",
      content_filter_clade: ""
    }
    post(:advanced_search_form, params: params)
    query = QueryRecord.last.query
    assert_equal("", query.params[:has_images])
    assert_true(query.params[:has_specimen])
    assert_false(query.params[:lichen])
    assert_equal("California", query.params[:region])
    assert_equal("", query.params[:clade])
  end

  # Prove that if advanced_search provokes exception,
  # it returns to advanced search form.
  def test_advanced_search_error
    ObservationsController.any_instance.stubs(:show_selected_observations).
      raises(RuntimeError)
    query = Query.lookup_and_save(:Observation, :advanced_search, name: "Fungi")
    get(:advanced_search, params: @controller.query_params(query))
    assert_redirected_to(action: :advanced_search_form)
  end

  def test_observation_search_help
    get_with_dump(:observation_search, pattern: "help:me")
    assert_match(/unexpected term/i, @response.body)
  end

  def test_observation_search
    pattern = "Boletus edulis"
    get_with_dump(:observation_search, pattern: pattern)
    assert_template(:index)
    assert_equal(
      :query_title_pattern_search.t(types: "Observations", pattern: pattern),
      @controller.instance_variable_get("@title")
    )
    assert_not_empty(css_select('[id="right_tabs"]').text, "Tabset is empty")

    get_with_dump(:observation_search, pattern: pattern, page: 2)
    assert_template(:index)
    assert_equal(
      :query_title_pattern_search.t(types: "Observations", pattern: pattern),
      @controller.instance_variable_get("@title")
    )
    assert_not_empty(css_select('[id="right_tabs"]').text, "Tabset is empty")

    # When there are no hits, no title is displayed, there's no rh tabset, and
    # html <title> contents are the action name
    pattern = "no hits"
    get_with_dump(:observation_search, pattern: pattern)
    assert_template(:index)
    assert_empty(@controller.instance_variable_get("@title"))
    assert_empty(css_select('[id="right_tabs"]').text, "Tabset should be empty")
    assert_equal(css_select("title").text,
                 "Mushroom Observer: Observation Search",
                 "metadata <title> tag incorrect")

    # If pattern is id of a real Observation, go directly to that Observation.
    obs = Observation.first
    get_with_dump(:observation_search, pattern: obs.id)
    assert_redirected_to(action: :show, id: Observation.first.id)
  end

  # Prove that when pattern is the id of a real observation,
  # goes directly to that observation.
  def test_observation_search_matching_id
    obs = observations(:minimal_unknown_obs)
    get(:observation_search, params: { pattern: obs.id })
    assert_redirected_to(%r{/#{obs.id}})
  end

  # Prove that when the pattern causes an error,
  # MO just displays an observation list
  def test_observation_search_bad_pattern
    get(:observation_search, params: { pattern: { error: "" } })
    assert_template(:index)
  end

  def test_map_observations
    get(:map_observations)
    assert_template(:map_observations)
  end

  def test_map_observation_hidden_gps
    obs = observations(:unknown_with_lat_long)
    get(:map_observation, params: { id: obs.id })
    assert_true(assigns(:observations).map(&:lat).map(&:to_s).join("").
                                       include?("34.1622"))
    assert_true(assigns(:observations).map(&:long).map(&:to_s).join("").
                                       include?("118.3521"))

    obs.update(gps_hidden: true)
    get(:map_observation, params: { id: obs.id })
    assert_false(assigns(:observations).map(&:lat).map(&:to_s).join("").
                                        include?("34.1622"))
    assert_false(assigns(:observations).map(&:long).map(&:to_s).join("").
                                        include?("118.3521"))
  end

  def test_map_observations_hidden_gps
    obs = observations(:unknown_with_lat_long)
    query = Query.lookup_and_save(:Observation, :by_user, user: mary.id)
    assert(query.result_ids.include?(obs.id))

    get(:map_observations, params: { q: query.id.alphabetize })
    assert_true(assigns(:observations).map(&:lat).map(&:to_s).join("").
                                       include?("34.1622"))
    assert_true(assigns(:observations).map(&:long).map(&:to_s).join("").
                                       include?("118.3521"))

    obs.update(gps_hidden: true)
    get(:map_observations, params: { q: query.id.alphabetize })
    assert_false(assigns(:observations).map(&:lat).map(&:to_s).join("").
                                        include?("34.1622"))
    assert_false(assigns(:observations).map(&:long).map(&:to_s).join("").
                                        include?("118.3521"))
  end

  def test_observation_search_with_spelling_correction
    # Missing the stupid genus Coprinus: breaks the alternate name suggestions.
    login("rolf")
    Name.find_or_create_name_and_parents("Coprinus comatus").each(&:save!)
    names = Name.suggest_alternate_spellings("Coprinus comatis")
    assert_not_equal([], names.map(&:search_name))

    get(:observation_search, params: { pattern: "coprinis comatis" })
    assert_template(:index)
    assert_equal("coprinis comatis", assigns(:suggest_alternate_spellings))
    assert_select("div.alert-warning", 1)
    assert_select("a[href *= 'observation_search?pattern=Coprinus+comatus']",
                  text: names(:coprinus_comatus).search_name)

    get(:observation_search, params: { pattern: "Coprinus comatus" })
    assert_response(:redirect)
  end

  # Created in response to a bug seen in the wild
  def test_where_search_next_page
    params = { place_name: "Burbank", page: 2 }
    get_with_dump(:observations_at_where, params)
    assert_template(:index)
  end

  # Created in response to a bug seen in the wild
  def test_where_search_pattern
    params = { place_name: "Burbank" }
    get_with_dump(:observations_at_where, params)
    assert_template(:index, partial: :_rss_log)
  end

  def test_observations_of_name
    params = { species_list_id: species_lists(:unknown_species_list).id,
               name: observations(:minimal_unknown_obs).name }
    get_with_dump(:observations_of_name, params)
    # Needs an assertion. Was
    # assert_select("title", /Observations of Synonyms of/)
    # but that broken by PR 497.
  end

  # Prove that lichen content_filter works on observations
  def test_observations_with_lichen_filter
    login(users(:lichenologist).name)
    get_with_dump(:index)
    results = @controller.instance_variable_get("@objects")

    assert(results.count.positive?)
    assert(results.all? { |result| result.lifeform.include?("lichen") },
           "All results should be lichen-ish")

    login(users(:antilichenologist).name)
    get_with_dump(:index)
    results = @controller.instance_variable_get("@objects")

    assert(results.count.positive?)
    assert(results.none? { |result| result.lifeform.include?(" lichen ") },
           "No results should be lichens")
  end


  #   ---------------
  #    show observation
  #   ---------------

  def test_show_observation_num_views
    obs = observations(:coprinus_comatus_obs)
    updated_at = obs.updated_at
    num_views = obs.num_views
    last_view = obs.last_view
    # obs.update_view_stats
    get_with_dump(:show, id: obs.id)
    obs.reload
    assert_equal(num_views + 1, obs.num_views)
    assert_not_equal(last_view, obs.last_view)
    assert_equal(updated_at, obs.updated_at)
  end

  def assert_show_observation
    assert_action_partials(:show_observation,
                           ["_show_name_info",
                            "_show_observation",
                            "_show_lists",
                            "namings/_show",
                            "_show_comments",
                            "_show_thumbnail_map",
                            "_show_images"])
  end

  def test_show_observation
    assert_equal(0, QueryRecord.count)

    # Test it on obs with no namings first.
    obs_id = observations(:unknown_with_no_naming).id
    get_with_dump(:show, id: obs_id)
    assert_show_observation
    assert_form_action(controller: :votes, action: :cast_votes, id: obs_id)

    # Test it on obs with two namings (Rolf's and Mary's), but no one logged in.
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show, id: obs_id)
    assert_show_observation
    assert_form_action(controller: :votes, action: :cast_votes, id: obs_id)

    # Test it on obs with two namings, with owner logged in.
    login("rolf")
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show, id: obs_id)
    assert_show_observation
    assert_form_action(controller: :votes, action: :cast_votes, id: obs_id)

    # Test it on obs with two namings, with non-owner logged in.
    login("mary")
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show, id: obs_id)
    assert_show_observation
    assert_form_action(controller: :votes, action: :cast_votes, id: obs_id)

    # Test a naming owned by the observer but the observer has 'No Opinion'.
    # Ensure that rolf owns @obs_with_no_opinion.
    user = login("rolf")
    obs = observations(:strobilurus_diminutivus_obs)
    assert_equal(obs.user, user)
    get(:show, params: { id: obs.id })
    assert_show_observation

    # Make sure no queries created for show_image links.
    assert_empty(QueryRecord.where("description like '%model=:Image%'"))
  end

  def test_show_observation_change_vote_anonymity
    obs = observations(:coprinus_comatus_obs)
    user = login(users(:public_voter).name)

    get_with_dump(:show, id: obs.id, go_private: 1)
    user.reload
    assert_equal(:yes, user.votes_anonymous)

    get_with_dump(:show, id: obs.id, go_public: 1)
    user.reload
    assert_equal(:no, user.votes_anonymous)
  end

  def test_show_owner_id
    login(user_with_view_owner_id_true)
    obs = observations(:owner_only_favorite_ne_consensus)
    get_with_dump(:show, id: obs.id)
    assert_select("div[class *= 'owner-id']",
                  { text: /#{obs.owner_preference.text_name}/,
                    count: 1 },
                  "Observation should show Observer ID")

    get_with_dump(:show,
                  id: observations(:owner_multiple_favorites).id)
    assert_select("div[class *= 'owner-id']",
                  { text: /#{:show_observation_no_clear_preference.t}/,
                    count: 1 },
                  "Observation should show lack of Observer preference")
  end

  def test_show_owner_id_view_owner_id_false
    login(user_with_view_owner_id_false)
    get_with_dump(:show,
                  id: observations(:owner_only_favorite_ne_consensus).id)
    assert_select("div[class *= 'owner-id']", { count: 0 },
                  "Do not show Observer ID when user has not opted for it")
  end

  def test_show_owner_id_noone_logged_in
    logout
    get_with_dump(:show,
                  id: observations(:owner_only_favorite_ne_consensus).id)
    assert_select("div[class *= 'owner-id']", { count: 0 },
                  "Do not show Observer ID when nobody logged in")
  end

  def user_with_view_owner_id_true
    users(:rolf).login
  end

  def user_with_view_owner_id_false
    users(:dick).login
  end

  def test_observation_external_links_exist
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show, id: obs_id)

    assert_select("a[href *= 'images.google.com']")
    assert_select("a[href *= 'mycoportal.org']")

    # There is a MycoBank link which includes taxon name and MycoBank language
    assert_select("a[href *= 'mycobank.org']") do
      assert_select("a[href *= '/Coprinus%20comatus']")
      assert_select("a[href *= 'Lang=Eng']")
    end
  end

  def test_show_observation_edit_links
    obs = observations(:detailed_unknown_obs)
    proj = projects(:bolete_project)
    assert_equal(mary.id, obs.user_id)  # owned by mary
    assert(obs.projects.include?(proj)) # owned by bolete project
    # dick is only member of bolete project
    assert_equal([dick.id], proj.user_group.users.map(&:id))

    login("rolf")
    get(:show, params: { id: obs.id })
    assert_select("a[href*=edit]", count: 0)
    assert_select("a[href*=destroy]", count: 0)
    assert_select("a[href*=add_image]", count: 0)
    assert_select("a[href*=remove_image]", count: 0)
    assert_select("a[href*=reuse_image]", count: 0)
    get(:edit, params: { id: obs.id })
    assert_response(:redirect)
    get(:destroy, params: { id: obs.id })
    assert_flash_error

    login("mary")
    get(:show, params: { id: obs.id })
    assert_select("a[href*=edit]", minimum: 1)
    assert_select("a[href*=destroy]", minimum: 1)
    assert_select("a[href*=add_image]", minimum: 1)
    assert_select("a[href*=remove_image]", minimum: 1)
    assert_select("a[href*=reuse_image]", minimum: 1)
    get(:edit, params: { id: obs.id })
    assert_response(:success)

    login("dick")
    get(:show, params: { id: obs.id })
    assert_select("a[href*=edit]", minimum: 1)
    assert_select("a[href*=destroy]", minimum: 1)
    assert_select("a[href*=add_image]", minimum: 1)
    assert_select("a[href*=remove_image]", minimum: 1)
    assert_select("a[href*=reuse_image]", minimum: 1)
    get(:edit, params: { id: obs.id })
    assert_response(:success)
    get(:destroy, params: { id: obs.id })
    assert_flash_success
  end

  def test_show_observation_specimen_stuff
    obs1 = observations(:strobilurus_diminutivus_obs)
    obs2 = observations(:minimal_unknown_obs)
    obs3 = observations(:detailed_unknown_obs)
    observations(:locally_sequenced_obs).sequences.
      first.update(observation: obs2)
    observations(:genbanked_obs).sequences.
      each { |s| s.update(observation: obs3) }
    obs2.reload
    obs3.reload

    # Obs1 has nothing, owned by rolf, not in project.
    assert_users_equal(rolf, obs1.user)
    assert_empty(obs1.projects)
    assert_empty(obs1.collection_numbers)
    assert_empty(obs1.herbarium_records)
    assert_empty(obs1.sequences)

    # Obs2 owned by mary, not in project,
    # one collection_number owned by mary,
    # one herbarium_record owned by rolf at NY (roy is curator),
    # one sequence owned by rolf.
    assert_users_equal(mary, obs2.user)
    assert_empty(obs2.projects)
    assert_operator(obs2.collection_numbers.count, :==, 1)
    assert_operator(obs2.herbarium_records.count, :==, 1)
    assert_operator(obs2.sequences.count, :==, 1)
    assert_false(obs2.herbarium_records.first.can_edit?(mary))
    assert_true(obs2.herbarium_records.first.can_edit?(rolf))
    assert_true(obs2.herbarium_records.first.can_edit?(roy))

    # Obs3 owned by mary, in bolete project (dick admin and member),
    # two collection_numbers owned by mary,
    # two herbarium_records, one owned by rolf at NY,
    #   one owned by mary at MycoFlora,
    # several sequences all owned by dick.
    assert_users_equal(mary, obs3.user)
    assert_equal("Bolete Project", obs3.projects.first.title)
    assert_true(obs3.can_edit?(dick))
    assert_operator(obs3.collection_numbers.count, :>, 1)
    assert_operator(obs3.herbarium_records.count, :>, 1)
    assert_operator(obs3.sequences.count, :>, 1)

    # Can't edit anything if not logged in.
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], false)
    assert_show_obs(:sequences, [], false)

    get(:show, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, false]],
                    false)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, false]],
                    false)

    get(:show, params: { id: obs3.id })
    assert_show_obs(:collection_numbers,
                    obs3.collection_numbers.map { |x| [x.id, false] },
                    false)
    assert_show_obs(:herbarium_records,
                    obs3.herbarium_records.map { |x| [x.id, false] },
                    false)
    assert_show_obs(:sequences,
                    obs3.sequences.map { |x| [x.id, false] },
                    false)

    # Katrina isn't associated in any way with any of these observations.
    login("katrina")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], false)
    # But any logged-in user can add sequence to any observation.
    assert_show_obs(:sequences, [], true)

    get(:show, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, false]],
                    false)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, false]],
                    true)

    get(:show, params: { id: obs3.id })
    assert_show_obs(:collection_numbers,
                    obs3.collection_numbers.map { |x| [x.id, false] },
                    false)
    assert_show_obs(:herbarium_records,
                    obs3.herbarium_records.map { |x| [x.id, false] },
                    false)
    assert_show_obs(:sequences,
                    obs3.sequences.map { |x| [x.id, false] },
                    true)

    # Roy is a curator at NY, so can add herbarium records, and modify existing
    # herbarium records attached to NY.
    login("roy")
    assert_true(roy.curated_herbaria.any?)
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], true)
    assert_show_obs(:sequences, [], true)

    get(:show, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, true]],
                    true)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, false]],
                    true)

    get(:show, params: { id: obs3.id })
    assert_show_obs(:collection_numbers,
                    obs3.collection_numbers.map { |x| [x.id, false] },
                    false)
    assert_show_obs(:herbarium_records,
                    obs3.herbarium_records.map { |x| [x.id, x.can_edit?(roy)] },
                    true)
    assert_show_obs(:sequences,
                    obs3.sequences.map { |x| [x.id, false] },
                    true)

    # Dick owns all of the sequences, is on obs3's project, and has a personal
    # herbarium.
    login("dick")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], true)
    assert_show_obs(:sequences, [], true)

    get(:show, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, false]],
                    true)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, true]],
                    true)

    get(:show, params: { id: obs3.id })
    assert_show_obs(:collection_numbers,
                    obs3.collection_numbers.map { |x| [x.id, true] },
                    true)
    assert_show_obs(:herbarium_records,
                    obs3.herbarium_records.map { |x| [x.id, false] },
                    true)
    assert_show_obs(:sequences,
                    obs3.sequences.map { |x| [x.id, true] },
                    true)

    # Rolf owns obs1 and owns one herbarium record for both obs2 and obs3,
    # and he is a curator at NYBG.
    login("rolf")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], true)
    assert_show_obs(:herbarium_records, [], true)
    assert_show_obs(:sequences, [], true)

    get(:show, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, true]],
                    true)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, false]],
                    true)

    get(:show, params: { id: obs3.id })
    assert_show_obs(:collection_numbers,
                    obs3.collection_numbers.map { |x| [x.id, false] }, false)
    assert_show_obs(
      :herbarium_records,
      obs3.herbarium_records.map { |x| [x.id, x.can_edit?(rolf)] },
      true
    )
    assert_show_obs(
      :sequences,
      obs3.sequences.map { |x| [x.id, false] },
      true
    )

    # Mary owns obs2 and obs3, but has nothing to do with obs1.
    login("mary")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], false)
    assert_show_obs(:sequences, [], true)

    get(:show, params: { id: obs2.id })
    assert_show_obs(
      :collection_numbers,
      [[obs2.collection_numbers.first.id, true]],
      true
    )
    assert_show_obs(
      :herbarium_records,
      [[obs2.herbarium_records.first.id, false]],
      true
    )
    assert_show_obs(
      :sequences,
      [[obs2.sequences.first.id, false]],
      true
    )

    get(:show, params: { id: obs3.id })
    assert_show_obs(
      :collection_numbers,
      obs3.collection_numbers.map { |x| [x.id, true] },
      true
    )
    assert_show_obs(
      :herbarium_records,
      obs3.herbarium_records.map { |x| [x.id, x.can_edit?(mary)] },
      true
    )
    assert_show_obs(
      :sequences,
      obs3.sequences.map { |x| [x.id, false] },
      true
    )

    # Make sure admins can do everything.
    make_admin("katrina")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], true)
    assert_show_obs(:herbarium_records, [], true)
    assert_show_obs(:sequences, [], true)

    get(:show, params: { id: obs2.id })
    assert_show_obs(
      :collection_numbers,
      [[obs2.collection_numbers.first.id, true]],
      true
    )
    assert_show_obs(
      :herbarium_records,
      [[obs2.herbarium_records.first.id, true]],
      true
    )
    assert_show_obs(
      :sequences,
      [[obs2.sequences.first.id, true]],
      true
    )

    get(:show, params: { id: obs3.id })
    assert_show_obs(
      :collection_numbers,
      obs3.collection_numbers.map { |x| [x.id, true] },
      true
    )
    assert_show_obs(
      :herbarium_records,
      obs3.herbarium_records.map { |x| [x.id, true] },
      true
    )
    assert_show_obs(
      :sequences,
      obs3.sequences.map { |x| [x.id, true] },
      true
    )
  end

  def assert_show_obs(types, items, can_add)
    type = types.to_s.chop
    selector = types == :collection_numbers && !can_add ? "i" : "li"
    assert_select("#observation_#{types} #{selector}",
                  items.count,
                  "Wrong number of #{types} shown.")
    if can_add
      assert(response.body.match(%r{href="/#{type}/new/}),
             "Expected to find a create link for #{types}.")
    else
      assert_not(response.body.match(%r{href="/#{type}/new/}),
                 "Expected not to find a create link for #{types}.")
    end

    items.each do |id, can_edit|
      if can_edit
        assert(response.body.match(%r{href="/#{type}/edit/#{id}}),
               "Expected to find an edit link for #{type} #{id}.")
      else
        assert_not(response.body.match(%r{href="/#{type}/edit/#{id}}),
                   "Expected not to find an edit link for #{type} #{id}.")
      end
    end
  end


  #   ---------------
  #    destroy observation
  #   ---------------

  def test_destroy_observation
    assert(obs = observations(:minimal_unknown_obs))
    id = obs.id
    params = { id: id.to_s }
    assert_equal("mary", obs.user.login)
    requires_user(:destroy,
                  [action: :show],
                  params, "mary")
    assert_redirected_to(action: :index)
    assert_raises(ActiveRecord::RecordNotFound) do
      obs = Observation.find(id)
    end
  end


  #   ---------------
  #    recalc
  #   ---------------

  # Prove that recalc redirects to show, and
  # corrects an Observation's name.
  def test_recalc
    # Make the consensus inaccurate
    obs = observations(:owner_only_favorite_eq_consensus)
    accurate_consensus = obs.name
    obs.name = names(:coprinus_comatus)
    obs.save

    # recalc
    login
    get(:recalc, params: { id: obs.id })
    obs.reload

    assert_redirected_to(action: :show, id: obs.id)
    assert_equal(accurate_consensus, obs.name)
  end


  #   ---------------
  #    export
  #   ---------------

  # Test setting export status of names and descriptions.
  def test_set_export_status
    name = names(:petigera)
    params = {
      id: name.id,
      type: "name",
      value: "1"
    }

    # Require login.
    get("set_export_status", params: params)
    assert_redirected_to(controller: :account, action: :login)

    # Require reviewer.
    login("dick")
    get("set_export_status", params: params)
    assert_flash_error
    logout

    # Require correct params.
    login("rolf")
    get("set_export_status", params: params.merge(id: 9999))
    assert_flash_error
    get("set_export_status", params: params.merge(type: "bogus"))
    assert_flash_error
    get("set_export_status", params: params.merge(value: "true"))
    assert_flash_error

    # Now check *correct* usage.
    assert_equal(true, name.reload.ok_for_export)
    get("set_export_status", params: params.merge(value: "0"))
    assert_redirected_to(controller: :names, action: :show_name, id: name.id)
    assert_equal(false, name.reload.ok_for_export)

    get("set_export_status", params: params.merge(value: "1"))
    assert_redirected_to(controller: :names, action: :show_name, id: name.id)
    assert_equal(true, name.reload.ok_for_export)

    get("set_export_status", params: params.merge(value: "1", return: true))
    assert_redirected_to("/")
  end

  def test_original_filename_visibility
    login("mary")
    obs_id = observations(:agaricus_campestris_obs).id

    rolf.keep_filenames = :toss
    rolf.save
    get(:show, params: { id: obs_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_but_hide
    rolf.save
    get(:show, params: { id: obs_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_and_show
    rolf.save
    get(:show, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))

    login("rolf") # owner

    rolf.keep_filenames = :toss
    rolf.save
    get(:show, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_but_hide
    rolf.save
    get(:show, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_and_show
    rolf.save
    get(:show, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))
  end

  # ------------------------------
  #  Test creating observations.
  # ------------------------------

  # Test "get" side of new.
  def test_create_observation
    requires_login(:new)
    assert_form_action(action: :new, approved_name: "")
    assert_input_value(:collection_number_name,
                       users(:rolf).legal_name)
    assert_input_value(:collection_number_number, "")
    assert_input_value(:herbarium_record_herbarium_name,
                       users(:rolf).preferred_herbarium_name)
    assert_input_value(:herbarium_record_herbarium_id, "")
    assert_true(@response.body.include?("Albion, Mendocino Co., California"))
    users(:rolf).update(location_format: :scientific)
    get(:new)
    assert_true(@response.body.include?("California, Mendocino Co., Albion"))
  end

  def test_construct_observation_approved_place_name
    where = "Albion, California, USA"
    generic_construct_observation(
      { observation: { place_name: where },
        name: { name: "Coprinus comatus" },
        approved_place_name: "" },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert_equal(where, obs.place_name)
  end

  def test_create_observation_with_collection_number
    generic_construct_observation(
      { observation: { specimen: "1" },
        collection_number: { name: "Billy Bob", number: "17-034" },
        name: { name: "Coprinus comatus" } },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.collection_numbers.count == 1)
  end

  def test_create_observation_with_used_collection_number
    generic_construct_observation(
      { observation: { specimen: "1" },
        collection_number: { name: "Rolf Singer", number: "1" },
        name: { name: "Coprinus comatus" } },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.collection_numbers.count == 1)
    assert_flash_warning
  end

  def test_create_observation_with_specimen_and_collector_but_no_number
    generic_construct_observation(
      { observation: { specimen: "1" },
        collection_number: { name: "Rolf Singer", number: "" },
        name: { name: "Coprinus comatus" } },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert_empty(obs.collection_numbers)
  end

  def test_create_observation_with_collection_number_but_no_specimen
    generic_construct_observation(
      { collection_number: { name: "Rolf Singer", number: "3141" },
        name: { name: "Coprinus comatus" } },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert_not(obs.specimen)
    assert_empty(obs.collection_numbers)
  end

  def test_create_observation_with_collection_number_but_no_collector
    generic_construct_observation(
      { observation: { specimen: "1" },
        collection_number: { name: "", number: "27-18A.2" },
        name: { name: "Coprinus comatus" } },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.collection_numbers.count == 1)
    col_num = obs.collection_numbers.first
    assert_equal(rolf.legal_name, col_num.name)
    assert_equal("27-18A.2", col_num.number)
  end

  def test_create_observation_with_herbarium_record
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: {
          herbarium_name: herbaria(:nybg_herbarium).auto_complete_name,
          herbarium_id: "1234"
        },
        name: { name: "Coprinus comatus" } },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.herbarium_records.count == 1)
  end

  def test_create_observation_with_herbarium_duplicate_label
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: {
          herbarium_name: herbaria(:nybg_herbarium).auto_complete_name,
          herbarium_id: "1234"
        },
        name: { name: "Cortinarius sp." } },
      0, 0, 0
    )
    assert_input_value(:herbarium_record_herbarium_name,
                       "NY - The New York Botanical Garden")
    assert_input_value(:herbarium_record_herbarium_id, "1234")
  end

  def test_create_observation_with_herbarium_no_id
    name = "Coprinus comatus"
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: {
          herbarium_name: herbaria(:nybg_herbarium).auto_complete_name,
          herbarium_id: ""
        },
        name: { name: name } },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert_true(obs.specimen)
    assert_equal(0, obs.herbarium_records.count)
  end

  def test_create_observation_with_herbarium_but_no_specimen
    generic_construct_observation(
      { herbarium_record:
                          { herbarium_name: herbaria(
                            :nybg_herbarium
                          ).auto_complete_name,
                            herbarium_id: "1234" },
        name: { name: "Coprinus comatus" } },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert_not(obs.specimen)
    assert(obs.herbarium_records.count.zero?)
  end

  def test_create_observation_with_new_nonpersonal_herbarium
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: { herbarium_name: "A Brand New Herbarium",
                            herbarium_id: "" },
        name: { name: "Coprinus comatus" } },
      1, 1, 0
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert_empty(obs.herbarium_records)
  end

  def test_create_observation_with_new_personal_herbarium
    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: { herbarium_name: katrina.personal_herbarium_name,
                            herbarium_id: "12345" },
        name: { name: "Coprinus comatus" } },
      1, 1, 0, katrina
    )
    obs = assigns(:observation)
    assert(obs.specimen)
    assert_equal(1, obs.herbarium_records.count)
    assert_not_empty(obs.herbarium_records)
    herbarium_record = obs.herbarium_records.first
    herbarium = herbarium_record.herbarium
    assert(herbarium.curator?(katrina))
    assert(herbarium.name.match(/Katrina/))
  end

  def test_create_simple_observation_with_approved_unique_name
    where = "Simple, Massachusetts, USA"
    generic_construct_observation(
      { observation: { place_name: where, thumb_image_id: "0" },
        name: { name: "Coprinus comatus" } },
      1, 1, 0
    )
    obs = assigns(:observation)
    nam = assigns(:naming)
    assert_equal(where, obs.where)
    assert_equal(names(:coprinus_comatus).id, nam.name_id)
    assert_equal("2.03659", format("%.5f", obs.vote_cache))
    assert_not_nil(obs.rss_log)
    # This was getting set to zero instead of nil if no images were uploaded
    # when obs was created.
    assert_nil(obs.thumb_image_id)
  end

  def test_create_simple_observation_of_unknown_taxon
    where = "Unknown, Massachusetts, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0)
    obs = assigns(:observation)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_new_name
    generic_construct_observation({
                                    name: { name: "New name" }
                                  }, 0, 0, 0)
  end

  def test_create_observation_with_approved_new_name
    # Test an observation creation with an approved new name
    generic_construct_observation({
                                    name: { name: "Argus arg-arg" },
                                    approved_name: "Argus arg-arg"
                                  }, 1, 1, 2)
  end

  def test_create_observation_with_approved_name_and_extra_space
    generic_construct_observation(
      { name: { name: "Another new-name" + "  " },
        approved_name: "Another new-name" + "  " },
      1, 1, 2
    )
  end

  def test_create_observation_with_approved_section
    # (This is now supported nominally)
    # (Use Macrocybe because it already exists and has an author.
    # That way we know it is actually creating a name for this section.)
    generic_construct_observation(
      { name: { name: "Macrocybe section Fakesection" },
        approved_name: "Macrocybe section Fakesection" },
      1, 1, 1
    )
  end

  def test_create_observation_with_approved_junk_name
    generic_construct_observation({
                                    name: {
                                      name: "This is a bunch of junk"
                                    },
                                    approved_name: "This is a bunch of junk"
                                  }, 0, 0, 0)
  end

  def test_create_observation_with_multiple_name_matches
    generic_construct_observation({
                                    name: { name: "Amanita baccata" }
                                  }, 0, 0, 0)
  end

  def test_create_observation_choosing_one_of_multiple_name_matches
    generic_construct_observation(
      { name: { name: "Amanita baccata" },
        chosen_name: { name_id: names(:amanita_baccata_arora).id } },
      1, 1, 0
    )
  end

  def test_create_observation_choosing_deprecated_one_of_multiple_name_matches
    generic_construct_observation(
      { name: { name: names(:pluteus_petasatus_deprecated).text_name } },
      1, 1, 0
    )
    nam = assigns(:naming)
    assert_equal(names(:pluteus_petasatus_approved).id, nam.name_id)
  end

  def test_create_observation_with_deprecated_name
    generic_construct_observation({
                                    name: { name: "Lactarius subalpinus" }
                                  }, 0, 0, 0)
  end

  def test_create_observation_with_chosen_approved_synonym_of_deprecated_name
    generic_construct_observation(
      { name: { name: "Lactarius subalpinus" },
        approved_name: "Lactarius subalpinus",
        chosen_name: { name_id: names(:lactarius_alpinus).id } },
      1, 1, 0
    )
    nam = assigns(:naming)
    assert_equal(nam.name, names(:lactarius_alpinus))
  end

  def test_create_observation_with_approved_deprecated_name
    generic_construct_observation(
      { name: { name: "Lactarius subalpinus" },
        approved_name: "Lactarius subalpinus",
        chosen_name: {} },
      1, 1, 0
    )
    nam = assigns(:naming)
    assert_equal(nam.name, names(:lactarius_subalpinus))
  end

  def test_create_observation_with_approved_new_species
    # Test an observation creation with an approved new name
    Name.find_by(text_name: "Agaricus").destroy
    generic_construct_observation({
                                    name: { name: "Agaricus novus" },
                                    approved_name: "Agaricus novus"
                                  }, 1, 1, 2)
    name = Name.find_by(text_name: "Agaricus novus")
    assert(name)
    assert_equal("Agaricus novus", name.text_name)
  end

  def test_create_observation_that_generates_email
    QueuedEmail.queue_emails(true)
    count_before = QueuedEmail.count
    name = names(:agaricus_campestris)
    flavor = Notification.flavors[:name]
    notifications = Notification.where(flavor: flavor, obj_id: name.id)
    assert_equal(2, notifications.length,
                 "Should be 2 name notifications for name ##{name.id}")

    where = "Simple, Massachusetts, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: name.text_name }
                                  }, 1, 1, 0)
    obs = assigns(:observation)
    nam = assigns(:naming)

    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_equal(name.id, nam.name_id) # Make sure it's the right name
    assert_not_nil(obs.rss_log)
    assert_equal(count_before + 2, QueuedEmail.count)
    QueuedEmail.queue_emails(false)
  end

  def test_create_observation_with_decimal_geolocation_and_unknown_name
    lat = 34.1622
    long = -118.3521
    generic_construct_observation({
                                    observation: { place_name: "",
                                                   lat: lat, long: long },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0)
    obs = assigns(:observation)

    assert_equal(lat.to_s, obs.lat.to_s)
    assert_equal(long.to_s, obs.long.to_s)
    assert_objs_equal(Location.unknown, obs.location)
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_dms_geolocation_and_unknown_name
    lat2 = "34°9’43.92”N"
    long2 = "118°21′7.56″W"
    generic_construct_observation({
                                    observation: { place_name: "",
                                                   lat: lat2, long: long2 },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0)
    obs = assigns(:observation)

    assert_equal("34.1622", obs.lat.to_s)
    assert_equal("-118.3521", obs.long.to_s)
    assert_objs_equal(Location.unknown, obs.location)
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_empty_geolocation_and_location
    # Make sure it doesn't accept no location AND no lat/long.
    generic_construct_observation({
                                    observation: { place_name: "",
                                                   lat: "", long: "" },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
  end

  def test_create_observations_with_unknown_location_and_empty_geolocation
    # But create observation if explicitly tell it "unknown" location.
    generic_construct_observation({
                                    observation: { place_name: "Earth",
                                                   lat: "", long: "" },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0)
  end

  def test_create_observation_with_various_altitude_formats
    [
      ["500",     500],
      ["500m",    500],
      ["500 ft.", 152],
      [" 500' ", 152]
    ].each do |input, output|
      where = "Unknown, Massachusetts, USA"

      generic_construct_observation({
                                      observation: { place_name: where,
                                                     alt: input },
                                      name: { name: "Unknown" }
                                    }, 1, 0, 0)
      obs = assigns(:observation)

      assert_equal(output, obs.alt)
      assert_equal(where, obs.where) # Make sure it's the right observation
      assert_not_nil(obs.rss_log)
    end
  end

  def test_create_observation_creating_class
    generic_construct_observation(
      { observation: { place_name: "Earth", lat: "", long: "" },
        name: { name: "Lecanoromycetes L." },
        approved_name: "Lecanoromycetes L." },
      1, 1, 1
    )
    name = Name.last
    assert_equal("Lecanoromycetes", name.text_name)
    assert_equal("L.", name.author)
    assert_equal(:Class, name.rank)
  end

  def test_create_observation_creating_family
    params = {
      observation: { place_name: "Earth", lat: "", long: "" },
      name: { name: "Acarosporaceae" },
      approved_name: "Acarosporaceae"
    }
    o_num = 1
    g_num = 1
    n_num = 1
    user = rolf
    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    score   = user.reload.contribution
    params  = modified_generic_params(params, user)

    post_requires_login(:create, params)
    name = Name.last

    # assert_redirected_to(action: :show)
    assert_response(:redirect)
    assert_match(%r{/test.host/\d+\Z}, @response.redirect_url)
    assert_equal(o_count + o_num, Observation.count, "Wrong Observation count")
    assert_equal(g_count + g_num, Naming.count, "Wrong Naming count")
    assert_equal(n_count + n_num, Name.count, "Wrong Name count")
    assert_equal(score + o_num + 2 * g_num + 10 * n_num,
                 user.reload.contribution,
                 "Wrong User score")
    assert_not_equal(
      0,
      @controller.instance_variable_get("@observation").thumb_image_id,
      "Wrong image id"
    )
    assert_equal("Acarosporaceae", name.text_name)
    assert_equal(:Family, name.rank)
  end

  def test_create_observation_creating_group
    generic_construct_observation(
      { observation: { place_name: "Earth", lat: "", long: "" },
        name: { name: "Morchella elata group" },
        approved_name: "Morchella elata group" },
      1, 1, 2
    )
    name = Name.last
    assert_equal("Morchella elata group", name.text_name)
    assert_equal("", name.author)
    assert_equal(:Group, name.rank)
  end

  def test_prevent_creation_of_species_under_deprecated_genus
    login("katrina")
    cladonia = Name.find_or_create_name_and_parents("Cladonia").last
    cladonia.save!
    cladonia_picta = Name.find_or_create_name_and_parents("Cladonia picta").last
    cladonia_picta.save!
    cladina = Name.find_or_create_name_and_parents("Cladina").last
    cladina.change_deprecated(true)
    cladina.save!
    cladina.merge_synonyms(cladonia)

    generic_construct_observation({
                                    observation: { place_name: "Earth" },
                                    name: { name: "Cladina pictum" }
                                  }, 0, 0, 0, roy)
    assert_names_equal(cladina, assigns(:parent_deprecated))
    assert_obj_list_equal([cladonia_picta], assigns(:valid_names))

    generic_construct_observation({
                                    observation: { place_name: "Earth" },
                                    name: { name: "Cladina pictum" },
                                    approved_name: "Cladina pictum"
                                  }, 1, 1, 1, roy)

    name = Name.last
    assert_equal("Cladina pictum", name.text_name)
    assert_true(name.deprecated)
  end

  def test_construct_observation_dubious_place_names
    # Test a reversed name with a scientific user
    where = "USA, Massachusetts, Reversed"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0, roy)

    # Test missing space.
    where = "Reversible, Massachusetts,USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    # (This is accepted now for some reason.)
    where = "USA,Massachusetts, Reversible"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0, roy)

    # Test a bogus country name
    where = "Bogus, Massachusetts, UAS"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    where = "UAS, Massachusetts, Bogus"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0, roy)

    # Test a bad state name
    where = "Bad State Name, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    where = "USA, Bad State Name"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0, roy)

    # Test mix of city and county
    where = "Burbank, Los Angeles Co., California, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    where = "USA, California, Los Angeles Co., Burbank"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0, roy)

    # Test mix of city and county
    where = "Falmouth, Barnstable Co., Massachusetts, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    where = "USA, Massachusetts, Barnstable Co., Falmouth"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0, roy)

    # Test some bad terms
    where = "Some County, Ohio, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    where = "Old Rd, Ohio, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    where = "Old Rd., Ohio, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0)

    # Test some acceptable additions
    where = "near Burbank, Southern California, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0)
  end

  def test_name_resolution
    login("rolf")

    params = {
      observation: {
        when: Time.zone.now,
        place_name: "Somewhere, Massachusetts, USA",
        specimen: "0",
        thumb_image_id: "0"
      },
      name: {},
      vote: { value: "3" }
    }
    expected_page = :create_location

    # Can we create observation with existing genus?
    agaricus = names(:agaricus)
    params[:name][:name] = "Agaricus"
    params[:approved_name] = nil
    post(:create, params: params)
    # assert_template(action: expected_page)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = "Agaricus sp"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = "Agaricus sp."
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    # Can we create observation with genus and add author?
    params[:name][:name] = "Agaricus Author"
    params[:approved_name] = "Agaricus Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal("Agaricus Author", agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = "Agaricus"
    agaricus.save

    params[:name][:name] = "Agaricus sp Author"
    params[:approved_name] = "Agaricus sp Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal("Agaricus Author", agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = "Agaricus"
    agaricus.save

    params[:name][:name] = "Agaricus sp. Author"
    params[:approved_name] = "Agaricus sp. Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal("Agaricus Author", agaricus.reload.search_name)

    # Can we create observation with genus specifying author?
    params[:name][:name] = "Agaricus Author"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = "Agaricus sp Author"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = "Agaricus sp. Author"
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus?
    psalliota = names(:psalliota)
    params[:name][:name] = "Psalliota"
    params[:approved_name] = "Psalliota"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = "Psalliota sp"
    params[:approved_name] = "Psalliota sp"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = "Psalliota sp."
    params[:approved_name] = "Psalliota sp."
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus, adding author?
    params[:name][:name] = "Psalliota Author"
    params[:approved_name] = "Psalliota Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal("Psalliota Author", psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = "Psalliota"
    psalliota.save

    params[:name][:name] = "Psalliota sp Author"
    params[:approved_name] = "Psalliota sp Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal("Psalliota Author", psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = "Psalliota"
    psalliota.save

    params[:name][:name] = "Psalliota sp. Author"
    params[:approved_name] = "Psalliota sp. Author"
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal("Psalliota Author", psalliota.reload.search_name)

    # Can we create new quoted genus?
    params[:name][:name] = '"One"'
    params[:approved_name] = '"One"'
    post(:create, params: params)
    # assert_template(controller: :observations, action: expected_page)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One"', assigns(:observation).name.search_name)

    params[:name][:name] = '"Two" sp'
    params[:approved_name] = '"Two" sp'
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"Two"', assigns(:observation).name.text_name)
    assert_equal('"Two"', assigns(:observation).name.search_name)

    params[:name][:name] = '"Three" sp.'
    params[:approved_name] = '"Three" sp.'
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"Three"', assigns(:observation).name.text_name)
    assert_equal('"Three"', assigns(:observation).name.search_name)

    params[:name][:name] = '"One"'
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp'
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp.'
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)

    # Can we create species under the quoted genus?
    params[:name][:name] = '"One" foo'
    params[:approved_name] = '"One" foo'
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One" foo', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" "bar"'
    params[:approved_name] = '"One" "bar"'
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One" "bar"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" Author'
    params[:approved_name] = '"One" Author'
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp Author'
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp. Author'
    params[:approved_name] = nil
    post(:create, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" Author', assigns(:observation).name.search_name)
  end

  def test_create_observation_strip_images
    login("rolf")

    setup_image_dirs
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    fixture = Rack::Test::UploadedFile.new(fixture, "image/jpeg")

    old_img1 = images(:turned_over_image)
    old_img2 = images(:in_situ_image)
    assert_false(old_img1.gps_stripped)
    assert_false(old_img2.gps_stripped)
    assert_false(old_img1.transferred)
    assert_false(old_img2.transferred)

    orig_file = old_img1.local_file_name("orig")
    path = orig_file.sub(%r{/[^/]*$}, "")
    FileUtils.mkdir_p(path) unless File.directory?(path)
    FileUtils.cp(fixture, orig_file)

    post(
      :create,
      observation: {
        when: Time.zone.now,
        place_name: "Burbank, California, USA",
        lat: "45.4545",
        long: "-90.1234",
        alt: "456",
        specimen: "0",
        thumb_image_id: "0",
        gps_hidden: "1"
      },
      image: {
        "0" => {
          image: fixture,
          copyright_holder: "me",
          when: Time.zone.now
        }
      },
      good_images: "#{old_img1.id} #{old_img2.id}"
    )

    obs = Observation.last
    assert_equal(3, obs.images.length)
    new_img = (obs.images - [old_img1, old_img2]).first
    assert_true(new_img.gps_stripped)
    # We have script/process_image disabled for tests, so it doesn't actually
    # strip the uploaded image.
    # assert_not_equal(File.size(fixture),
    #                  File.size(new_img.local_file_name("orig")))

    # Make sure it stripped the image which had already been created.
    assert_true(old_img1.reload.gps_stripped)
    assert_not_equal(File.size(fixture),
                     File.size(old_img1.local_file_name("orig")))

    # Second pre-existing image has missing file, so stripping should fail.
    assert_false(old_img2.reload.gps_stripped)
  end

  # ----------------------------------------------------------------
  #  Test edit, both "get" and "post".
  # ----------------------------------------------------------------

  # (Sorry, these used to all be edit/update_observation, now they're
  # confused because of the naming stuff.)
  def test_edit_observation_get
    obs = observations(:coprinus_comatus_obs)
    assert_equal("rolf", obs.user.login)
    params = { id: obs.id.to_s }
    requires_user(:edit, [controller: :observations,
                                      action: :show], params)

    assert_form_action(action: :edit, id: obs.id.to_s)

    # image notes field must be textarea -- not just text -- because text
    # is inline and would drops any newlines in the image notes
    assert_select("textarea[id = 'good_image_#{obs.images.first.id}_notes']",
                  count: 1)
  end

  def test_edit_observation
    obs = observations(:detailed_unknown_obs)
    updated_at = obs.rss_log.updated_at
    new_where = "Somewhere In, Japan"
    new_notes = { other: "blather blather blather" }
    new_specimen = false
    img = images(:in_situ_image)
    params = {
      id: obs.id.to_s,
      observation: {
        notes: new_notes,
        place_name: new_where,
        "when(1i)" => "2001",
        "when(2i)" => "2",
        "when(3i)" => "3",
        specimen: new_specimen,
        thumb_image_id: "0"
      },
      good_images: "#{img.id} #{images(:turned_over_image).id}",
      good_image: {
        img.id.to_s => {
          notes: "new notes",
          original_name: "new name",
          copyright_holder: "someone else",
          "when(1i)" => "2012",
          "when(2i)" => "4",
          "when(3i)" => "6",
          license_id: licenses(:ccwiki30).id.to_s
        }
      },
      log_change: { checked: "1" }
    }
    post_requires_user(:edit, [controller: :observations,
                                           action: :show],
                       params, "mary")
    # assert_redirected_to(controller: :locations, action: :new)
    assert_redirected_to(/#{url_for(controller: :locations,
                                    action: :new)}/)
    assert_equal(10, rolf.reload.contribution)
    obs = assigns(:observation)
    assert_equal(new_where, obs.where)
    assert_equal("2001-02-03", obs.when.to_s)
    assert_equal(new_notes, obs.notes)
    assert_equal(new_specimen, obs.specimen)
    assert_not_equal(updated_at, obs.rss_log.updated_at)
    assert_not_equal(0, obs.thumb_image_id)
    img = img.reload
    assert_equal("new notes", img.notes)
    assert_equal("new name", img.original_name)
    assert_equal("someone else", img.copyright_holder)
    assert_equal("2012-04-06", img.when.to_s)
    assert_equal(licenses(:ccwiki30), img.license)
  end

  def test_edit_observation_no_logging
    obs = observations(:detailed_unknown_obs)
    updated_at = obs.rss_log.updated_at
    where = "Somewhere, China"
    params = {
      id: obs.id.to_s,
      observation: {
        place_name: where,
        when: obs.when,
        notes: obs.notes,
        specimen: obs.specimen
      },
      log_change: { checked: "0" }
    }
    post_requires_user(
      :edit,
      [controller: :observations, action: :show],
      params, "mary"
    )
    # assert_redirected_to(controller: :locations, action: :new)
    assert_redirected_to(%r{/locations/new})
    assert_equal(10, rolf.reload.contribution)
    obs = assigns(:observation)
    assert_equal(where, obs.where)
    assert_equal(updated_at, obs.rss_log.updated_at)
  end

  def test_edit_observation_bad_place_name
    obs = observations(:detailed_unknown_obs)
    new_where = "test_update_observation"
    new_notes = { other: "blather blather blather" }
    new_specimen = false
    params = {
      id: obs.id.to_s,
      observation: {
        place_name: new_where,
        "when(1i)" => "2001",
        "when(2i)" => "2",
        "when(3i)" => "3",
        notes: new_notes,
        specimen: new_specimen,
        thumb_image_id: "0"
      },
      log_change: { checked: "1" }
    }
    post_requires_user(
      :edit,
      [controller: :observations, action: :show],
      params, "mary"
    )
    assert_response(:success) # Which really means failure
  end

  def test_edit_observation_with_another_users_image
    img1 = images(:in_situ_image)
    img2 = images(:turned_over_image)
    img3 = images(:commercial_inquiry_image)

    obs = observations(:detailed_unknown_obs)
    obs.images << img3
    obs.save
    obs.reload

    assert_equal(img1.user_id, obs.user_id)
    assert_equal(img2.user_id, obs.user_id)
    assert_not_equal(img3.user_id, obs.user_id)

    img_ids = obs.images.map(&:id)
    assert_equal([img1.id, img2.id, img3.id], img_ids)

    old_img1_notes = img1.notes
    old_img3_notes = img3.notes

    params = {
      id: obs.id.to_s,
      observation: {
        place_name: obs.place_name,
        when: obs.when,
        notes: obs.notes,
        specimen: obs.specimen,
        thumb_image_id: "0"
      },
      good_images: img_ids.map(&:to_s).join(" "),
      good_image: {
        img2.id.to_s => { notes: "new notes for two" },
        img3.id.to_s => { notes: "new notes for three" }
      }
    }
    login("mary")
    post(:edit, params: params)
    assert_redirected_to(action: :show)
    assert_flash_success
    assert_equal(old_img1_notes, img1.reload.notes)
    assert_equal("new notes for two", img2.reload.notes)
    assert_equal(old_img3_notes, img3.reload.notes)
  end

  def test_edit_observation_with_non_image
    obs = observations(:minimal_unknown_obs)
    file = Rack::Test::UploadedFile.new(
      Rails.root.join("test", "fixtures", "projects.yml").to_s, "text/plain"
    )
    params = {
      id: obs.id,
      observation: {
        place_name: obs.place_name,
        when: obs.when,
        notes: obs.notes,
        specimen: obs.specimen,
        thumb_image_id: "0"
      },
      good_images: "",
      good_image: {},
      image: {
        "0" => {
          image: file,
          when: Time.zone.now
        }
      }
    }
    login("mary")
    post(:edit, params: params)

    # 200 :success means means failure!
    assert_response(
      :success,
      "Expected 200 (OK), Got #{@response.status} (#{@response.message})"
    )
    assert_flash_error
  end

  def test_edit_observation_strip_images
    login("mary")
    obs = observations(:detailed_unknown_obs)

    setup_image_dirs
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    fixture = Rack::Test::UploadedFile.new(fixture, "image/jpeg")

    old_img1 = images(:turned_over_image)
    old_img2 = images(:in_situ_image)
    assert_false(old_img1.gps_stripped)
    assert_false(old_img2.gps_stripped)

    orig_file = old_img1.local_file_name("orig")
    path = orig_file.sub(%r{/[^/]*$}, "")
    FileUtils.mkdir_p(path) unless File.directory?(path)
    FileUtils.cp(fixture, orig_file)

    post(
      :edit,
      id: obs.id,
      observation: {
        gps_hidden: "1"
      },
      image: {
        "0" => {
          image: fixture,
          copyright_holder: "me",
          when: Time.zone.now
        }
      }
    )

    obs.reload
    old_img1.reload
    old_img2.reload

    assert_equal(3, obs.images.length)
    new_img = (obs.images - [old_img1, old_img2]).first

    assert_true(new_img.gps_stripped)
    # We have script/process_image disabled for tests, so it doesn't actually
    # strip the uploaded image.
    # assert_not_equal(File.size(fixture),
    #                  File.size(new_img.local_file_name("orig")))

    # Make sure it stripped the image which had already been created.
    assert_true(old_img1.reload.gps_stripped)
    assert_not_equal(File.size(fixture),
                     File.size(old_img1.local_file_name("orig")))

    # Second pre-existing image has missing file, so stripping should fail.
    assert_false(old_img2.reload.gps_stripped)
  end

  # --------------------------------------------------------------------
  #  Test notes with template new, and edit,
  #  both "get" and "post".
  # --------------------------------------------------------------------

  # Prove that new renders note fields with template keys first,
  # in the order listed in the template
  def test_create_observation_with_notes_template_get
    user = users(:notes_templater)
    login(user.login)
    get(:new)

    assert_page_has_correct_notes_areas(
      expect_areas: { Cap: "", Nearby_trees: "", odor: "", Other: "" }
    )
  end

  # Prove that notes are saved with template keys first, in the order listed in
  # the template, then Other, but without blank fields
  def test_create_observation_with_notes_template_post
    user = users(:notes_templater)
    params = { observation: sample_obs_fields }
    # Use defined Location to avoid issues with reloading Observation
    params[:observation][:place_name] = locations(:albion).name
    params[:observation][:notes] = {
      Nearby_trees: "?",
      Observation.other_notes_key => "Some notes",
      odor: "",
      Cap: "red"
    }
    expected_notes = {
      Cap: "red",
      Nearby_trees: "?",
      Observation.other_notes_key => "Some notes"
    }
    o_size = Observation.count

    login(user.login)
    post(:create, params: params)

    assert_equal(o_size + 1, Observation.count)
    obs = Observation.last.reload
    assert_redirected_to(action: :show, id: obs.id)
    assert_equal(expected_notes, obs.notes)
  end

  # Prove that edit has correct note fields and content:
  # Template fields first, in template order; then orphaned fields in order
  # in which they appear in observation, then Other
  def test_edit_observation_with_notes_template_get
    obs    = observations(:templater_noteless_obs)
    user   = obs.user
    params = {
      id: obs.id,
      observation: {
        place_name: obs.location.name,
        lat: "",
        long: "",
        alt: "",
        "when(1i)" => obs.when.year,
        "when(2i)" => obs.when.month,
        "when(3i)" => obs.when.day,
        specimen: "0",
        thumb_image_id: "0",
        notes: obs.notes
      },
      herbarium_record: default_herbarium_record_fields,
      username: user.login,
      vote: { value: "3" }
    }

    login(user.login)
    get(:edit, params: params)
    assert_page_has_correct_notes_areas(
      expect_areas: { Cap: "", Nearby_trees: "", odor: "",
                      Observation.other_notes_key => "" }
    )

    obs         = observations(:templater_other_notes_obs)
    params[:id] = obs.id
    params[:observation][:notes] = obs.notes
    get(:edit, params: params)
    assert_page_has_correct_notes_areas(
      expect_areas: { Cap: "", Nearby_trees: "", odor: "",
                      Observation.other_notes_key => "some notes" }
    )
  end

  def test_edit_observation_with_notes_template_post
    # Prove notes_template works when editing Observation without notes
    obs = observations(:templater_noteless_obs)
    user = obs.user
    notes = {
      Cap: "dark red",
      Nearby_trees: "?",
      odor: "farinaceous"
    }
    params = {
      id: obs.id,
      observation: { notes: notes }
    }
    login(user.login)
    post(:edit, params: params)

    assert_redirected_to(action: :show, id: obs.id)
    assert_equal(notes, obs.reload.notes)
  end

  # -----------------------------------
  #  Test extended observation forms.
  # -----------------------------------

  def test_javascripty_name_reasons
    login("rolf")

    # If javascript isn't enabled, then checkbox isn't required.
    post(:create,
         params: {
           observation: { place_name: "Where, Japan", when: Time.zone.now },
           name: { name: names(:coprinus_comatus).text_name },
           vote: { value: 3 },
           reason: {
             "1" => { check: "0", notes: ""    },
             "2" => { check: "0", notes: "foo" },
             "3" => { check: "1", notes: ""    },
             "4" => { check: "1", notes: "bar" }
           }
         })
    assert_response(:redirect) # redirected = successfully created
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.get_reasons.select(&:used?).map(&:num).sort
    assert_equal([2, 3, 4], reasons)

    # If javascript IS enabled, then checkbox IS required.
    post(:create,
         params: {
           observation: { place_name: "Where, Japan", when: Time.zone.now },
           name: { name: names(:coprinus_comatus).text_name },
           vote: { value: 3 },
           reason: {
             "1" => { check: "0", notes: ""    },
             "2" => { check: "0", notes: "foo" },
             "3" => { check: "1", notes: ""    },
             "4" => { check: "1", notes: "bar" }
           },
           was_js_on: "yes"
         })
    assert_response(:redirect) # redirected = successfully created
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.get_reasons.select(&:used?).map(&:num).sort
    assert_equal([3, 4], reasons)
  end

  def test_create_with_image_upload
    login("rolf")

    time0 = Time.utc(2000)
    time1 = Time.utc(2001)
    time2 = Time.utc(2002)
    time3 = Time.utc(2003)
    week_ago = 1.week.ago

    setup_image_dirs
    file = "#{::Rails.root}/test/images/Coprinus_comatus.jpg"
    file1 = Rack::Test::UploadedFile.new(file, "image/jpeg")
    file2 = Rack::Test::UploadedFile.new(file, "image/jpeg")
    file3 = Rack::Test::UploadedFile.new(file, "image/jpeg")

    new_image1 = Image.create(
      copyright_holder: "holder_1",
      when: time1,
      notes: "notes_1",
      user_id: users(:rolf).id,
      image: file1,
      content_type: "image/jpeg",
      created_at: week_ago
    )

    new_image2 = Image.create(
      copyright_holder: "holder_2",
      when: time2,
      notes: "notes_2",
      user_id: users(:rolf).id,
      image: file2,
      content_type: "image/jpeg",
      created_at: week_ago
    )

    # assert(new_image1.updated_at < 1.day.ago)
    # assert(new_image2.updated_at < 1.day.ago)
    File.stub(:rename, false) do
      post(
        :new,
        params: {
          observation: {
            place_name: "Zzyzx, Japan",
            when: time0,
            thumb_image_id: 0, # (make new image the thumbnail)
            notes: { Observation.other_notes_key => "blah" }
          },
          image: {
            "0" => {
              image: file3,
              copyright_holder: "holder_3",
              when: time3,
              notes: "notes_3"
            }
          },
          good_image: {
            new_image1.id.to_s => {
            },
            new_image2.id.to_s => {
              notes: "notes_2_new"
            }
          },
          # (attach these two images once observation created)
          good_images: "#{new_image1.id} #{new_image2.id}"
        }
      )
    end
    assert_response(:redirect) # redirected = successfully created

    obs = Observation.find_by(where: "Zzyzx, Japan")
    assert_equal(rolf.id, obs.user_id)
    assert_equal(time0, obs.when)
    assert_equal("Zzyzx, Japan", obs.place_name)

    new_image1.reload
    new_image2.reload
    imgs = obs.images.sort_by(&:id)
    img_ids = imgs.map(&:id)
    assert_equal([new_image1.id, new_image2.id, new_image2.id + 1], img_ids)
    assert_equal(new_image2.id + 1, obs.thumb_image_id)
    assert_equal("holder_1", imgs[0].copyright_holder)
    assert_equal("holder_2", imgs[1].copyright_holder)
    assert_equal("holder_3", imgs[2].copyright_holder)
    assert_equal(time1, imgs[0].when)
    assert_equal(time2, imgs[1].when)
    assert_equal(time3, imgs[2].when)
    assert_equal("notes_1",     imgs[0].notes)
    assert_equal("notes_2_new", imgs[1].notes)
    assert_equal("notes_3",     imgs[2].notes)
    # assert(imgs[0].updated_at < 1.day.ago) # notes not changed
    # assert(imgs[1].updated_at > 1.day.ago) # notes changed
  end

  def test_image_upload_when_create_fails
    login("rolf")

    setup_image_dirs
    file = "#{::Rails.root}/test/images/Coprinus_comatus.jpg"
    file = Rack::Test::UploadedFile.new(file, "image/jpeg")
    File.stub(:rename, false) do
      post(
        :new,
        params: {
          observation: {
            place_name: "", # will cause failure
            when: Time.zone.now
          },
          image: { "0": { image: file,
                          copyright_holder: "zuul",
                          when: Time.zone.now } }
        }
      )
      assert_response(:success) # success = failure, paradoxically
    end
    # Make sure image was created, but that it is unattached, and that it has
    # been kept in the @good_images array for attachment later.
    img = Image.find_by(copyright_holder: "zuul")
    assert(img)
    assert_equal([], img.observations)
    assert_equal([img.id],
                 @controller.instance_variable_get("@good_images").map(&:id))
  end

  def test_image_upload_when_process_image_fails
    login("rolf")

    setup_image_dirs
    file = "#{::Rails.root}/test/images/Coprinus_comatus.jpg"
    file = Rack::Test::UploadedFile.new(file, "image/jpeg")

    # Simulate process_image failure.
    Image.any_instance.stubs(:process_image).returns(false)

    post(
      :new,
      params: {
        observation: {
          place_name: "USA",
          when: Time.current
        },
        image: {
          "0" => {
            image: file,
            copyright_holder: "zuul",
            when: Time.current
          }
        }
      }
    )

    # Prove that an image was created, but that it is unattached, is in the
    # @bad_images array, and has not been kept in the @good_images array
    # for attachment later.
    img = Image.find_by(copyright_holder: "zuul")
    assert(img)
    assert_equal([], img.observations)
    assert_includes(@controller.instance_variable_get("@bad_images"), img)
    assert_empty(@controller.instance_variable_get("@good_images"))
  end

  def test_project_checkboxes_in_create_observation
    init_for_project_checkbox_tests

    login("rolf")
    get(:new)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)

    login("dick")
    get(:new)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)

    # Should have different default
    # if recently posted observation attached to project.
    obs = Observation.create!
    @proj2.add_observation(obs)
    get(:new)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :checked)

    # Make sure it remember state of checks if submit fails.
    post(:create,
         params: {
           name: { name: "Screwy Name" }, # (ensures it will fail)
           project: { "id_#{@proj1.id}" => "0" }
         })
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)
  end

  def test_project_checkboxes_in_edit_observation
    init_for_project_checkbox_tests

    login("rolf")
    get(:edit, params: { id: @obs1.id })
    assert_response(:redirect)
    get(:edit, params: { id: @obs2.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
    post(
      :edit,
      params: {
        id: @obs2.id,
        observation: { place_name: "blah blah blah" },  # (ensures it will fail)
        project: { "id_#{@proj1.id}" => "1" }
      }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    post(:edit,
         params: {
           id: @obs2.id,
           project: { "id_#{@proj1.id}" => "1" }
         })
    assert_response(:redirect)
    assert_obj_list_equal([@proj1], @obs2.reload.projects)
    assert_obj_list_equal([@proj1], @img2.reload.projects)

    login("mary")
    get(:edit, params: { id: @obs2.id })
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    get(:edit, params: { id: @obs1.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :checked)
    post(
      :edit,
      params: {
        id: @obs1.id,
        observation: { place_name: "blah blah blah" },  # (ensures it will fail)
        project: {
          "id_#{@proj1.id}" => "1",
          "id_#{@proj2.id}" => "0"
        }
      }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :unchecked)
    post(
      :edit,
      params: {
        id: @obs1.id,
        project: {
          "id_#{@proj1.id}" => "1",
          "id_#{@proj2.id}" => "1"
        }
      }
    )
    assert_response(:redirect)
    assert_obj_list_equal([@proj1, @proj2], @obs1.reload.projects, :sort)
    assert_obj_list_equal([@proj1, @proj2], @img1.reload.projects, :sort)

    login("dick")
    get(:edit, params: { id: @obs2.id })
    assert_response(:redirect)
    get(:edit, params: { id: @obs1.id })
    assert_project_checks(@proj1.id => :checked_but_disabled,
                          @proj2.id => :checked)
  end

  def init_for_project_checkbox_tests
    @proj1 = projects(:eol_project)
    @proj2 = projects(:bolete_project)
    @obs1 = observations(:detailed_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @img1 = @obs1.images.first
    @img2 = @obs2.images.first
  end

  def assert_project_checks(project_states)
    project_states.each do |id, state|
      assert_checkbox_state("project_id_#{id}", state)
    end
  end

  def test_list_checkboxes_in_create_observation
    init_for_list_checkbox_tests

    login("rolf")
    get(:new)
    assert_list_checks(@spl1.id => :unchecked, @spl2.id => :no_field)

    login("mary")
    get(:new)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)

    login("katrina")
    get(:new)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :no_field)

    # Dick is on project that owns @spl2.
    login("dick")
    get(:new)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)

    # Should have different default
    # if recently posted observation attached to project.
    obs = Observation.create!
    @spl1.add_observation(obs) # (shouldn't affect anything for create)
    @spl2.add_observation(obs)
    get(:new)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :checked)

    # Make sure it remember state of checks if submit fails.
    post(:create,
         params: {
           name: { name: "Screwy Name" }, # (ensures it will fail)
           list: { "id_#{@spl2.id}" => "0" }
         })
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)
  end

  def test_list_checkboxes_in_edit_observation
    init_for_list_checkbox_tests

    login("rolf")
    get(:edit, params: { id: @obs1.id })
    assert_list_checks(@spl1.id => :unchecked, @spl2.id => :no_field)
    spl_start_length = @spl1.observations.length
    post(
      :edit,
      params: {
        id: @obs1.id,
        observation: { place_name: "blah blah blah" }, # (ensures it will fail)
        list: { "id_#{@spl1.id}" => "1" }
      }
    )
    assert_equal(spl_start_length, @spl1.reload.observations.length)
    assert_list_checks(@spl1.id => :checked, @spl2.id => :no_field)
    post(
      :edit,
      params: {
        id: @obs1.id,
        list: { "id_#{@spl1.id}" => "1" }
      }
    )
    assert_equal(spl_start_length + 1, @spl1.reload.observations.length)
    assert_response(:redirect)
    assert_obj_list_equal([@spl1], @obs1.reload.species_lists)
    get(:edit, params: { id: @obs2.id })
    assert_response(:redirect)

    login("mary")
    get(:edit, params: { id: @obs1.id })
    assert_response(:redirect)
    get(:edit, params: { id: @obs2.id })
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :checked)
    @spl1.add_observation(@obs2)
    get(:edit, params: { id: @obs2.id })
    assert_list_checks(@spl1.id => :checked_but_disabled, @spl2.id => :checked)

    login("dick")
    get(:edit, params: { id: @obs2.id })
    assert_list_checks(@spl1.id => :checked_but_disabled, @spl2.id => :checked)
  end

  def init_for_list_checkbox_tests
    @spl1 = species_lists(:first_species_list)
    @spl2 = species_lists(:unknown_species_list)
    @obs1 = observations(:unlisted_rolf_obs)
    @obs2 = observations(:detailed_unknown_obs)
    assert_users_equal(rolf, @spl1.user)
    assert_users_equal(mary, @spl2.user)
    assert_users_equal(rolf, @obs1.user)
    assert_users_equal(mary, @obs2.user)
    assert_obj_list_equal([], @obs1.species_lists)
    assert_obj_list_equal([@spl2], @obs2.species_lists)
  end

  def assert_list_checks(list_states)
    list_states.each do |id, state|
      assert_checkbox_state("list_id_#{id}", state)
    end
  end

  # ----------------------------
  #  Interest in Show Observation.
  # ----------------------------

  def test_interest_in_show_observation
    login("rolf")
    minimal_unknown = observations(:minimal_unknown_obs)

    # No interest in this observation yet.
    #
    # <img[^>]+watch\d*.png[^>]+>[\w\s]*
    get(:show, params: { id: minimal_unknown.id })
    assert_response(:success)
    assert_image_link_in_html(
      /watch\d*.png/,
      controller: :interests, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 1
    )
    assert_image_link_in_html(
      /ignore\d*.png/,
      controller: :interests, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: -1
    )

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.create(target: minimal_unknown, user: rolf, state: true)
    get(:show, params: { id: minimal_unknown.id })
    assert_response(:success)
    assert_image_link_in_html(
      /halfopen\d*.png/,
      controller: :interests, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 0
    )
    assert_image_link_in_html(
      /ignore\d*.png/,
      controller: :interests, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: -1
    )

    # Destroy that interest, create new one with interest off.
    Interest.where(user_id: rolf.id).last.destroy
    Interest.create(target: minimal_unknown, user: rolf, state: false)
    get(:show, params: { id: minimal_unknown.id })
    assert_response(:success)
    assert_image_link_in_html(
      /halfopen\d*.png/,
      controller: :interests, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 0
    )
    assert_image_link_in_html(
      /watch\d*.png/,
      controller: :interests, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 1
    )
  end

  ###################

  def test_change_banner
    use_test_locales do
      # Oops!  One of these tags actually exists now!
      TranslationString.where(tag: "app_banner_box").each(&:destroy)

      str1 = TranslationString.create!(
        language: languages(:english),
        tag: :app_banner_box,
        text: "old banner",
        user: User.admin
      )
      str1.update_localization

      str2 = TranslationString.create!(
        language: languages(:french),
        tag: :app_banner_box,
        text: "banner ancienne",
        user: User.admin
      )
      str2.update_localization

      get(:change_banner)
      assert_redirected_to(controller: :account, action: :login)

      login("rolf")
      get(:change_banner)
      assert_flash_error
      assert_redirected_to(action: :index)

      make_admin("rolf")
      get(:change_banner)
      assert_no_flash
      assert_response(:success)
      assert_textarea_value(:val, :app_banner_box.l)

      post(:change_banner, params: { val: "new banner" })
      assert_no_flash
      assert_redirected_to(action: :index)
      assert_equal("new banner", :app_banner_box.l)

      strs = TranslationString.where(tag: :app_banner_box)
      strs.each do |str|
        assert_equal("new banner", str.text,
                     "Didn't change text of #{str.language.locale} correctly.")
      end
    end
  end

  def test_javascript_override
    get(:turn_javascript_on)
    assert_response(:redirect)
    assert_equal(:on, session[:js_override])

    get(:turn_javascript_off)
    assert_response(:redirect)
    assert_equal(:off, session[:js_override])

    get(:turn_javascript_nil)
    assert_response(:redirect)
    assert_nil(session[:js_override])
  end

  # Prove w3c_tests renders html, with all content within the <body>
  # (and therefore without MO's layout).
  def test_w3c_tests
    expect_start = "<html><head></head><body>"
    get(:w3c_tests)
    assert_equal(expect_start, @response.body[0..(expect_start.size - 1)])
  end

  def test_index_observation_by_past_by
    get(:index_observation, params: { by: :modified })
    assert_response(:success)
    get(:index_observation, params: { by: :created })
    assert_response(:success)
  end

  def test_download_observation_index
    obs = Observation.where(user: mary)
    assert(obs.length >= 4)
    query = Query.lookup_and_save(:Observation, :by_user, user: mary.id)

    # Add herbarium_record to fourth obs for testing purposes.
    login("mary")
    fourth = obs.fourth
    fourth.herbarium_records << HerbariumRecord.create!(
      herbarium: herbaria(:nybg_herbarium),
      user: mary,
      initial_det: fourth.name.text_name,
      accession_number: "Mary #1234"
    )

    get(:download_observations, params: { q: query.id.alphabetize })
    assert_no_flash
    assert_response(:success)

    post(
      :download_observations,
      params: {
        q: query.id.alphabetize,
        format: :raw,
        encoding: "UTF-8",
        commit: "Cancel"
      }
    )
    assert_no_flash
    # assert_redirected_to(action: :index_observation)
    assert_redirected_to(%r{/index_observation})

    post(
      :download_observations,
      params: {
        q: query.id.alphabetize,
        format: :raw,
        encoding: "UTF-8",
        commit: "Download"
      }
    )
    rows = @response.body.split("\n")
    ids = rows.map { |s| s.sub(/,.*/, "") }
    expected = %w[observation_id] + obs.map { |o| o.id.to_s }
    last_expected_index = expected.length - 1

    assert_no_flash
    assert_response(:success)
    assert_equal(expected, ids[0..last_expected_index],
                 "Exported 1st column incorrect")
    last_row = rows[last_expected_index].chomp
    o = obs.last
    nm = o.name
    l = o.location
    country = l.name.split(", ")[-1]
    state =   l.name.split(", ")[-2]
    city =    l.name.split(", ")[-3]

    # Hard coded values below come from the actual
    # part of a test failure message.
    # If fixtures change, these may also need to be changed.
    assert_equal(
      "#{o.id},#{mary.id},mary,Mary Newbie,#{o.when}," \
        "X,\"#{o.try(:herbarium_records).map(&:herbarium_label).join(", ")}\","\
        "#{nm.id},#{nm.text_name},#{nm.author},#{nm.rank},0.0," \
        "#{l.id},#{country},#{state},,#{city}," \
        ",,,34.22,34.15,-118.29,-118.37," \
        "#{l.high.to_f.round},#{l.low.to_f.round}," \
        "#{"X" if o.is_collection_location},#{o.thumb_image_id}," \
        "#{o.notes[Observation.other_notes_key]}," \
        "#{MO.http_domain}/#{o.id}",
      last_row.iconv("utf-8"),
      "Exported last row incorrect"
    )

    post(
      :download_observations,
      params: {
        q: query.id.alphabetize,
        format: "raw",
        encoding: "ASCII",
        commit: "Download"
      }
    )
    assert_no_flash
    assert_response(:success)

    post(
      :download_observations,
      params: {
        q: query.id.alphabetize,
        format: "raw",
        encoding: "UTF-16",
        commit: "Download"
      }
    )
    assert_no_flash
    assert_response(:success)

    post(
      :download_observations,
      params: {
        q: query.id.alphabetize,
        format: "adolf",
        encoding: "UTF-8",
        commit: "Download"
      }
    )
    assert_no_flash
    assert_response(:success)

    post(
      :download_observations,
      params: {
        q: query.id.alphabetize,
        format: "darwin",
        encoding: "UTF-8",
        commit: "Download"
      }
    )
    assert_no_flash
    assert_response(:success)

    post(
      :download_observations,
      params: {
        q: query.id.alphabetize,
        format: "symbiota",
        encoding: "UTF-8",
        commit: "Download"
      }
    )
    assert_no_flash
    assert_response(:success)
  end

  def test_print_labels
    query = Query.lookup_and_save(:Observation, :by_user, user: mary.id)
    assert_operator(query.num_results, :>=, 4)
    get(:print_labels, params: { q: query.id.alphabetize })
    assert_select("div#labels td", query.num_results)
    assert_match(/314159/, @response.body) # make sure mycoflora id in there!
    assert_match(/Mary Newbie 174/, @response.body) # and collection number!

    # Alternative entry point.
    post(
      :download_observations,
      params: {
        q: query.id.alphabetize,
        commit: "Print Labels"
      }
    )
    assert_select("div#labels td", query.num_results)
  end

  def test_normal_permissions
    get :intro
    assert_equal(200, @response.status)
    get :textile
    assert_equal(200, @response.status)
  end

  def test_robot_permissions
    @request.user_agent = "Googlebot"
    get :intro
    assert_equal(200, @response.status)
    get :textile
    assert_equal(403, @response.status)
  end

  def test_external_sites_user_can_add_links_to
    # not logged in
    do_external_sites_test([], nil, nil)
    # dick is neither owner nor member of any site's project
    do_external_sites_test([], dick, observations(:agaricus_campestris_obs))
    # rolf is owner
    do_external_sites_test(ExternalSite.all, rolf,
                           observations(:agaricus_campestris_obs))
    # mary is member some sites' project
    do_external_sites_test(mary.external_sites, mary,
                           observations(:agaricus_campestris_obs))
    # but there is already a link on this obs
    do_external_sites_test([], mary, observations(:coprinus_comatus_obs))
  end

  def do_external_sites_test(expect, user, obs)
    @controller.instance_variable_set("@user", user)
    actual = @controller.external_sites_user_can_add_links_to(obs)
    assert_equal(expect.map(&:name), actual.map(&:name))
  end

  def test_suggestions
    obs = observations(:detailed_unknown_obs)
    name1  = names(:coprinus_comatus)
    name2a = names(:lentinellus_ursinus_author1)
    name2b = names(:lentinellus_ursinus_author2)
    obs.name = name2b
    obs.vote_cache = 2.0
    obs.save
    assert_not_nil(obs.thumb_image)
    assert_obj_list_equal([], name2a.reload.observations)
    assert_obj_list_equal([obs], name2b.reload.observations)
    suggestions = '[[["Coprinus comatus",0.7654],' \
                    '["Lentinellus ursinus",0.321]]]'
    requires_login(:suggestions, id: obs.id, names: suggestions)
    data = @controller.instance_variable_get("@suggestions")
    assert_equal(2, data.length)
    data = data.sort_by(&:max).reverse
    assert_names_equal(name1, data[0].name)
    assert_names_equal(name2b, data[1].name)
    assert_equal(0.7654, data[0].max)
    assert_equal(0.321, data[1].max)
    assert_objs_equal(obs, data[1].image_obs)
  end
end
