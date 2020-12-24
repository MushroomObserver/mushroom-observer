# frozen_string_literal: true

require("test_helper")

class ObserverControllerTest < FunctionalTestCase
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

    post_requires_login(:create_observation, params)

    begin
      if o_num.zero?
        assert_response(:success)
      elsif location_exists_or_place_name_blank(params)
        # assert_redirected_to(action: :show_observation)
        assert_response(:redirect)
        assert_match(%r{/test.host/\d+\Z}, @response.redirect_url)
      else
        assert_redirected_to(%r{/location/create_location})
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

  ##############################################################################

  # ----------------------------
  #  General tests.
  # ----------------------------

  def test_show_observation_noteless_image
    obs = observations(:peltigera_rolf_obs)
    img = images(:rolf_profile_image)
    assert_nil(img.notes)
    assert(obs.images.member?(img))
    get_with_dump(:show_observation, id: obs.id)
  end

  def test_show_observation_noteful_image
    obs = observations(:detailed_unknown_obs)
    get_with_dump(:show_observation, id: obs.id)
  end

  def test_show_observation_change_thumbnail_size
    user = users(:small_thumbnail_user)
    login(user.name)
    get(:show_observation,
        params: { set_thumbnail_size: :thumbnail })
    user.reload
    assert_equal(:thumbnail, user.thumbnail_size)
  end

  def test_show_observation_hidden_gps
    obs = observations(:unknown_with_lat_long)
    get(:show_observation, params: { id: obs.id })
    assert_match(/34.1622|118.3521/, @response.body)

    obs.update(gps_hidden: true)
    get(:show_observation, params: { id: obs.id })
    assert_no_match(/34.1622|118.3521/, @response.body)

    login("mary")
    get(:show_observation, params: { id: obs.id })
    assert_match(/34.1622|118.3521/, @response.body)
    assert_match(:show_observation_gps_hidden.t, @response.body)
  end

  def test_show_obs
    obs = observations(:fungi_obs)
    get(:show_obs,
        params: { id: obs.id })
    assert_redirected_to(action: :show_observation, id: obs.id)
  end

  def test_show_obs_view_stats
    obs = observations(:minimal_unknown_obs)
    assert_empty(ObservationView.where(observation: obs))
    get(:show_observation, params: { id: obs.id })
    assert_empty(ObservationView.where(observation: obs))
    assert_select("p.footer-view-stats") do |p|
      assert_includes(p.to_s, :footer_viewed.t(date: :footer_never.l,
                                               times: :many_times.l(num: 0)))
    end

    last_view = 1.hour.ago
    obs.update!(last_view: last_view)
    login("dick")
    get(:show_observation, params: { id: obs.id })
    assert_equal(1, ObservationView.where(observation: obs).count)
    assert_operator(obs.last_viewed_by(dick), :>=, 2.seconds.ago)
    assert_select("p.footer-view-stats") do |p|
      assert_includes(p.to_s, :footer_viewed.t(date: last_view.web_time,
                                               times: :one_time.l))
      assert_includes(p.to_s, :footer_last_you_viewed.t(date: :footer_never.l))
    end

    last_view = 2.months.ago
    obs.update!(last_view: last_view)
    obs.observation_views.where(user: dick).first.update!(last_view: last_view)
    get(:show_observation, params: { id: obs.id })
    assert_equal(1, ObservationView.where(observation: obs).count)
    assert_operator(obs.last_viewed_by(dick), :>=, 2.seconds.ago)
    assert_select("p.footer-view-stats") do |p|
      assert_includes(p.to_s, :footer_viewed.t(date: last_view.web_time,
                                               times: :many_times.l(num: 2)))
      assert_includes(p.to_s,
                      :footer_last_you_viewed.t(date: last_view.web_time))
    end
  end

  def test_page_loads
    get_with_dump(:index)
    assert_template(:list_rss_logs, partial: :_rss_log)
    assert_link_in_html(:app_intro.t, controller: :observer, action: :intro)
    assert_link_in_html(:app_create_account.t, controller: :account,
                                               action: :signup)

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

    get_with_dump(:list_observations)
    assert_template(:list_observations, partial: :_rss_log)

    # Test again, this time specifying page number via an observation id.
    get(:list_observations,
        params: { id: observations(:agaricus_campestris_obs).id })
    assert_template(:list_observations, partial: :_rss_log)

    get(:observations_for_project,
        params: { id: projects(:bolete_project).id })
    assert_template(:list_observations, partial: :_rss_log)

    get_with_dump(:list_rss_logs)
    assert_template(:list_rss_logs, partial: :_rss_log)

    get_with_dump(:news)
    assert_template(:news)

    get_with_dump(:observations_by_name)
    assert_template(:list_observations, partial: :_rss_log)

    get(:observations_of_name,
        params: { name: names(:boletus_edulis).text_name })
    assert_template(:list_observations, partial: :_rss_log)

    get(:observations_of_look_alikes,
        params: { name: names(:tremella_mesenterica).text_name })
    assert_template(:list_observations)

    get(:observations_of_related_taxa,
        params: { name: names(:tremella_mesenterica).text_name })
    assert_template(:list_observations)

    get_with_dump(:rss)
    assert_template(:rss)

    get_with_dump(:show_rss_log, id: rss_logs(:observation_rss_log).id)
    assert_template(:show_rss_log)

    get_with_dump(:users_by_contribution)
    assert_template(:users_by_contribution)

    get_with_dump(:show_user, id: rolf.id)
    assert_template(:show_user)

    get_with_dump(:observations_by_user, id: rolf.id)
    assert_template(:list_observations, partial: :_rss_log)

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
    assert_template(:list_rss_logs)

    # Show one.
    post(:index_rss_log,
         params: { show_observations: observations(:minimal_unknown_obs).to_s })
    assert_template(:list_rss_logs)

    # Show all.
    params = {}
    RssLog.all_types.each { |type| params["show_#{type}"] = "1" }
    post(:index_rss_log, params: params)
    assert_template(:list_rss_logs, partial: rss_logs(:observation_rss_log).id)
  end

  def test_get_index_rss_log
    # With params[:type], it should display only that type
    expect = rss_logs(:glossary_term_rss_log)
    get(:index_rss_log,
        params: { type: :glossary_term })
    assert_match(/#{expect.glossary_term.name}/, css_select(".rss-what").text)
    assert_no_match(/#{rss_logs(:observation_rss_log).observation.name}/,
                    css_select(".rss-what").text)

    # Without params[:type], it should display all logs
    get(:index_rss_log)
    assert_match(/#{expect.glossary_term.name}/, css_select(".rss-what").text)
    assert_match(/#{rss_logs(:observation_rss_log).observation.name.text_name}/,
                 css_select(".rss-what").text)
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
    get(:next_observation, params: { id: o_chron.fourth.id })
    assert_redirected_to(action: :show_observation, id: o_chron.third.id,
                         params: @controller.query_params(QueryRecord.last))

    get(:prev_observation, params: { id: o_chron.fourth.id })
    assert_redirected_to(action: :show_observation, id: o_chron.fifth.id,
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

    get(:next_observation, params: qp.merge(id: o_id))
    assert_redirected_to(action: :show_observation, id: o_id, params: qp)
    assert_flash_text(/can.*t find.*results.*index/i)
    get(:next_observation, params: qp.merge(id: o1.id))
    assert_redirected_to(action: :show_observation, id: o2.id, params: qp)
    get(:next_observation, params: qp.merge(id: o2.id))
    assert_redirected_to(action: :show_observation, id: o3.id, params: qp)
    get(:next_observation, params: qp.merge(id: o3.id))
    assert_redirected_to(action: :show_observation, id: o4.id, params: qp)
    get(:next_observation, params: qp.merge(id: o4.id))
    assert_redirected_to(action: :show_observation, id: o4.id, params: qp)
    assert_flash_text(/no more/i)

    get(:prev_observation, params: qp.merge(id: o4.id))
    assert_redirected_to(action: :show_observation, id: o3.id, params: qp)
    get(:prev_observation, params: qp.merge(id: o3.id))
    assert_redirected_to(action: :show_observation, id: o2.id, params: qp)
    get(:prev_observation, params: qp.merge(id: o2.id))
    assert_redirected_to(action: :show_observation, id: o1.id, params: qp)
    get(:prev_observation, params: qp.merge(id: o1.id))
    assert_redirected_to(action: :show_observation, id: o1.id, params: qp)
    assert_flash_text(/no more/i)
    get(:prev_observation, params: qp.merge(id: o_id))
    assert_redirected_to(action: :show_observation, id: o_id, params: qp)
    assert_flash_text(/can.*t find.*results.*index/i)
  end

  def test_advanced_search_form
    [Name, Image, Observation].each do |model|
      post(
        "advanced_search_form",
        params: {
          search: {
            name: "Don't know",
            user: "myself",
            model: model.name.underscore,
            content: "Long pink stem and small pink cap",
            location: "Eastern Oklahoma"
          },
          commit: "Search"
        }
      )
      assert_response(:redirect)
      assert_match(%r{#{model.show_controller}/advanced_search},
                   redirect_to_url)
    end
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Observation, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    get(:advanced_search, params: @controller.query_params(query))
    assert_template(:list_observations)
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
    assert_equal(["California"], query.params[:region])
    assert_equal("", query.params[:clade])
  end

  # Prove that if advanced_search provokes exception,
  # it returns to advanced search form.
  def test_advanced_search_error
    ObserverController.any_instance.stubs(:show_selected_observations).
      raises(RuntimeError)
    query = Query.lookup_and_save(:Observation, :advanced_search, name: "Fungi")
    get(:advanced_search, params: @controller.query_params(query))
    assert_redirected_to(action: "advanced_search_form")
  end

  def test_pattern_search
    params = { search: { pattern: "12", type: :observation } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :observer, action: :observation_search,
                         pattern: "12")

    params = { search: { pattern: "34", type: :image } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :image, action: :image_search,
                         pattern: "34")

    params = { search: { pattern: "56", type: :name } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :name, action: :name_search,
                         pattern: "56")

    params = { search: { pattern: "78", type: :location } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :location, action: :location_search,
                         pattern: "78")

    params = { search: { pattern: "90", type: :comment } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :comment, action: :comment_search,
                         pattern: "90")

    params = { search: { pattern: "12", type: :species_list } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :species_list,
                         action: :species_list_search,
                         pattern: "12")

    params = { search: { pattern: "34", type: :user } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :observer, action: :user_search,
                         pattern: "34")

    stub_request(:any, /google.com/)
    pattern =  "hexiexiva"
    params = { search: { pattern: pattern, type: :google } }
    target =
      "https://google.com/search?q=site%3Amushroomobserver.org+#{pattern}"
    get_with_dump(:pattern_search, params)
    assert_redirected_to(target)

    params = { search: { pattern: "", type: :google } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :observer, action: :list_rss_logs)

    params = { search: { pattern: "x", type: :nonexistent_type } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :observer, action: :list_rss_logs)

    params = { search: { pattern: "", type: :observation } }
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :observer, action: :list_observations)

    # Make sure this redirects correctly to list_herbaria not list_herariums.
    params = { search: { pattern: "", type: :herbarium } }
    get(:pattern_search, params: params)
    assert_redirected_to(controller: :herbarium, action: :list_herbaria)
  end

  def test_observation_search_help
    get_with_dump(:observation_search, pattern: "help:me")
    assert_match(/unexpected term/i, @response.body)
  end

  def test_observation_search
    pattern = "Boletus edulis"
    get_with_dump(:observation_search, pattern: pattern)
    assert_template(:list_observations)
    assert_equal(
      :query_title_pattern_search.t(types: "Observations", pattern: pattern),
      @controller.instance_variable_get("@title")
    )
    assert_not_empty(css_select('[id="right_tabs"]').text, "Tabset is empty")

    get_with_dump(:observation_search, pattern: pattern, page: 2)
    assert_template(:list_observations)
    assert_equal(
      :query_title_pattern_search.t(types: "Observations", pattern: pattern),
      @controller.instance_variable_get("@title")
    )
    assert_not_empty(css_select('[id="right_tabs"]').text, "Tabset is empty")

    # When there are no hits, no title is displayed, there's no rh tabset, and
    # html <title> contents are the action name
    pattern = "no hits"
    get_with_dump(:observation_search, pattern: pattern)
    assert_template(:list_observations)
    assert_empty(@controller.instance_variable_get("@title"))
    assert_empty(css_select('[id="right_tabs"]').text, "Tabset should be empty")
    assert_equal(css_select("title").text,
                 "Mushroom Observer: Observation Search",
                 "metadata <title> tag incorrect")

    # If pattern is id of a real Observation, go directly to that Observation.
    obs = Observation.first
    get_with_dump(:observation_search, pattern: obs.id)
    assert_redirected_to(action: :show_observation, id: Observation.first.id)
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
    assert_template(:list_observations)
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
    assert_template(:list_observations)
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
    assert_template(:list_observations)
  end

  # Created in response to a bug seen in the wild
  def test_where_search_pattern
    params = { place_name: "Burbank" }
    get_with_dump(:observations_at_where, params)
    assert_template(:list_observations, partial: :_rss_log)
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
    get_with_dump(:list_observations)
    results = @controller.instance_variable_get("@objects")

    assert(results.count.positive?)
    assert(results.all? { |result| result.lifeform.include?("lichen") },
           "All results should be lichen-ish")

    login(users(:antilichenologist).name)
    get_with_dump(:list_observations)
    results = @controller.instance_variable_get("@objects")

    assert(results.count.positive?)
    assert(results.none? { |result| result.lifeform.include?(" lichen ") },
           "No results should be lichens")
  end

  def test_observations_with_region_filter
    login(users(:californian).name)
    get(:list_observations)
    expect = Observation.where("`where` LIKE '%California, USA'").to_a
    results = @controller.instance_variable_get("@objects")
    assert_obj_list_equal(expect.sort_by(&:id), results.sort_by(&:id))
  end

  def test_send_webmaster_question
    ask_webmaster_test("rolf@mushroomobserver.org",
                       response: { controller: :observer,
                                   action: :list_rss_logs })
  end

  def test_send_webmaster_question_need_address
    ask_webmaster_test("", flash: :runtime_ask_webmaster_need_address.t)
  end

  def test_send_webmaster_question_spammer
    ask_webmaster_test("spammer", flash: :runtime_ask_webmaster_need_address.t)
  end

  def test_send_webmaster_question_need_content
    ask_webmaster_test("bogus@email.com",
                       content: "",
                       flash: :runtime_ask_webmaster_need_content.t)
  end

  def test_send_webmaster_question_antispam
    disable_unsafe_html_filter
    ask_webmaster_test("bogus@email.com",
                       content: "Buy <a href='http://junk'>Me!</a>",
                       flash: :runtime_ask_webmaster_antispam.t)
    ask_webmaster_test("okay_user@email.com",
                       content: "iwxobjUzvkhmaCt",
                       flash: :runtime_ask_webmaster_antispam.t)
  end

  def ask_webmaster_test(email, args)
    response = args[:response] || :success
    flash = args[:flash]
    post(:ask_webmaster_question,
         params: {
           user: { email: email },
           question: { content: (args[:content] || "Some content") }
         })
    assert_response(response)
    assert_flash_text(flash) if flash
  end

  def test_show_observation_num_views
    obs = observations(:coprinus_comatus_obs)
    updated_at = obs.updated_at
    num_views = obs.num_views
    last_view = obs.last_view
    # obs.update_view_stats
    get_with_dump(:show_observation, id: obs.id)
    obs.reload
    assert_equal(num_views + 1, obs.num_views)
    assert_not_equal(last_view, obs.last_view)
    assert_equal(updated_at, obs.updated_at)
  end

  def assert_show_observation
    assert_action_partials("show_observation",
                           ["_show_name_info",
                            "_show_observation",
                            "_show_lists",
                            "naming/_show",
                            "_show_comments",
                            "_show_thumbnail_map",
                            "_show_images"])
  end

  def test_show_observation
    assert_equal(0, QueryRecord.count)

    # Test it on obs with no namings first.
    obs_id = observations(:unknown_with_no_naming).id
    get_with_dump(:show_observation, id: obs_id)
    assert_show_observation
    assert_form_action(controller: :vote, action: :cast_votes, id: obs_id)

    # Test it on obs with two namings (Rolf's and Mary's), but no one logged in.
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show_observation, id: obs_id)
    assert_show_observation
    assert_form_action(controller: :vote, action: :cast_votes, id: obs_id)

    # Test it on obs with two namings, with owner logged in.
    login("rolf")
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show_observation, id: obs_id)
    assert_show_observation
    assert_form_action(controller: :vote, action: :cast_votes, id: obs_id)

    # Test it on obs with two namings, with non-owner logged in.
    login("mary")
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show_observation, id: obs_id)
    assert_show_observation
    assert_form_action(controller: :vote, action: :cast_votes, id: obs_id)

    # Test a naming owned by the observer but the observer has 'No Opinion'.
    # Ensure that rolf owns @obs_with_no_opinion.
    user = login("rolf")
    obs = observations(:strobilurus_diminutivus_obs)
    assert_equal(obs.user, user)
    get(:show_observation, params: { id: obs.id })
    assert_show_observation

    # Make sure no queries created for show_image links.
    assert_empty(QueryRecord.where("description like '%model=:Image%'"))
  end

  def test_show_observation_change_vote_anonymity
    obs = observations(:coprinus_comatus_obs)
    user = login(users(:public_voter).name)

    get_with_dump(:show_observation, id: obs.id, go_private: 1)
    user.reload
    assert_equal(:yes, user.votes_anonymous)

    get_with_dump(:show_observation, id: obs.id, go_public: 1)
    user.reload
    assert_equal(:no, user.votes_anonymous)
  end

  def test_show_owner_id
    login(user_with_view_owner_id_true)
    obs = observations(:owner_only_favorite_ne_consensus)
    get_with_dump(:show_observation, id: obs.id)
    assert_select("div[class *= 'owner-id']",
                  { text: /#{obs.owner_preference.text_name}/,
                    count: 1 },
                  "Observation should show Observer ID")

    get_with_dump(:show_observation,
                  id: observations(:owner_multiple_favorites).id)
    assert_select("div[class *= 'owner-id']",
                  { text: /#{:show_observation_no_clear_preference.t}/,
                    count: 1 },
                  "Observation should show lack of Observer preference")
  end

  def test_show_owner_id_view_owner_id_false
    login(user_with_view_owner_id_false)
    get_with_dump(:show_observation,
                  id: observations(:owner_only_favorite_ne_consensus).id)
    assert_select("div[class *= 'owner-id']", { count: 0 },
                  "Do not show Observer ID when user has not opted for it")
  end

  def test_show_owner_id_noone_logged_in
    logout
    get_with_dump(:show_observation,
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
    get_with_dump(:show_observation, id: obs_id)

    assert_select("a[href *= 'images.google.com']")
    assert_select("a[href *= 'mycoportal.org']")

    # There is a MycoBank link which includes taxon name and MycoBank language
    assert_select("a[href *= 'mycobank.org']") do
      assert_select("a[href *= '/Coprinus%20comatus']")
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
    get(:show_observation, params: { id: obs.id })
    assert_select("a[href*=edit_observation]", count: 0)
    assert_select("a[href*=destroy_observation]", count: 0)
    assert_select("a[href*=add_image]", count: 0)
    assert_select("a[href*=remove_image]", count: 0)
    assert_select("a[href*=reuse_image]", count: 0)
    get(:edit_observation, params: { id: obs.id })
    assert_response(:redirect)
    get(:destroy_observation, params: { id: obs.id })
    assert_flash_error

    login("mary")
    get(:show_observation, params: { id: obs.id })
    assert_select("a[href*=edit_observation]", minimum: 1)
    assert_select("a[href*=destroy_observation]", minimum: 1)
    assert_select("a[href*=add_image]", minimum: 1)
    assert_select("a[href*=remove_image]", minimum: 1)
    assert_select("a[href*=reuse_image]", minimum: 1)
    get(:edit_observation, params: { id: obs.id })
    assert_response(:success)

    login("dick")
    get(:show_observation, params: { id: obs.id })
    assert_select("a[href*=edit_observation]", minimum: 1)
    assert_select("a[href*=destroy_observation]", minimum: 1)
    assert_select("a[href*=add_image]", minimum: 1)
    assert_select("a[href*=remove_image]", minimum: 1)
    assert_select("a[href*=reuse_image]", minimum: 1)
    get(:edit_observation, params: { id: obs.id })
    assert_response(:success)
    get(:destroy_observation, params: { id: obs.id })
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
    #   one owned by mary at FunDiS,
    # several sequences all owned by dick.
    assert_users_equal(mary, obs3.user)
    assert_equal("Bolete Project", obs3.projects.first.title)
    assert_true(obs3.can_edit?(dick))
    assert_operator(obs3.collection_numbers.count, :>, 1)
    assert_operator(obs3.herbarium_records.count, :>, 1)
    assert_operator(obs3.sequences.count, :>, 1)

    # Can't edit anything if not logged in.
    get(:show_observation, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], false)
    assert_show_obs(:sequences, [], false)

    get(:show_observation, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, false]],
                    false)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, false]],
                    false)

    get(:show_observation, params: { id: obs3.id })
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
    get(:show_observation, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], false)
    # But any logged-in user can add sequence to any observation.
    assert_show_obs(:sequences, [], true)

    get(:show_observation, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, false]],
                    false)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, false]],
                    true)

    get(:show_observation, params: { id: obs3.id })
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
    get(:show_observation, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], true)
    assert_show_obs(:sequences, [], true)

    get(:show_observation, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, true]],
                    true)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, false]],
                    true)

    get(:show_observation, params: { id: obs3.id })
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
    get(:show_observation, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], true)
    assert_show_obs(:sequences, [], true)

    get(:show_observation, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, false]],
                    true)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, true]],
                    true)

    get(:show_observation, params: { id: obs3.id })
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
    get(:show_observation, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], true)
    assert_show_obs(:herbarium_records, [], true)
    assert_show_obs(:sequences, [], true)

    get(:show_observation, params: { id: obs2.id })
    assert_show_obs(:collection_numbers,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records,
                    [[obs2.herbarium_records.first.id, true]],
                    true)
    assert_show_obs(:sequences,
                    [[obs2.sequences.first.id, false]],
                    true)

    get(:show_observation, params: { id: obs3.id })
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
    get(:show_observation, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], false)
    assert_show_obs(:herbarium_records, [], false)
    assert_show_obs(:sequences, [], true)

    get(:show_observation, params: { id: obs2.id })
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

    get(:show_observation, params: { id: obs3.id })
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
    get(:show_observation, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, [], true)
    assert_show_obs(:herbarium_records, [], true)
    assert_show_obs(:sequences, [], true)

    get(:show_observation, params: { id: obs2.id })
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

    get(:show_observation, params: { id: obs3.id })
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
      assert(response.body.match(%r{href="/#{type}/create_#{type}/}),
             "Expected to find a create link for #{types}.")
    else
      assert_not(response.body.match(%r{href="/#{type}/create_#{type}/}),
                 "Expected not to find a create link for #{types}.")
    end

    items.each do |id, can_edit|
      if can_edit
        assert(response.body.match(%r{href="/#{type}/edit_#{type}/#{id}}),
               "Expected to find an edit link for #{type} #{id}.")
      else
        assert_not(response.body.match(%r{href="/#{type}/edit_#{type}/#{id}}),
                   "Expected not to find an edit link for #{type} #{id}.")
      end
    end
  end

  def test_show_user_no_id
    get_with_dump(:show_user)
    assert_redirected_to(action: :index_user)
  end

  def test_ask_questions
    id = observations(:coprinus_comatus_obs).id
    requires_login(:ask_observation_question, id: id)
    assert_form_action(action: :ask_observation_question, id: id)

    id = mary.id
    requires_login(:ask_user_question, id: id)
    assert_form_action(action: :ask_user_question, id: id)

    id = images(:in_situ_image).id
    requires_login(:commercial_inquiry, id: id)
    assert_form_action(action: :commercial_inquiry, id: id)

    # Prove that trying to ask question of user who refuses questions
    # redirects to that user's page (instead of an email form).
    user = users(:no_general_questions_user)
    login(user.name)
    get(:ask_user_question, params: { id: user.id })
    assert_flash_text(:permission_denied.t)
  end

  def test_destroy_observation
    assert(obs = observations(:minimal_unknown_obs))
    id = obs.id
    params = { id: id.to_s }
    assert_equal("mary", obs.user.login)
    requires_user(:destroy_observation,
                  [{ action: :show_observation }],
                  params, "mary")
    assert_redirected_to(action: :list_observations)
    assert_raises(ActiveRecord::RecordNotFound) do
      obs = Observation.find(id)
    end
  end

  def test_destroy_observation_failure
    obs = observations(:minimal_unknown_obs)
    params = { id: obs.id.to_s }
    login(obs.user.login)

    Observation.any_instance.stubs(:destroy).returns(false)
    post(:destroy_observation, params: params)

    assert_redirected_to(/#{obs.id}/)
    assert_not(obs.destroyed?)
    assert(Observation.where(id: obs.id).exists?)
  end

  # Prove that recalc redirects to show_observation, and
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

    assert_redirected_to(action: :show_observation, id: obs.id)
    assert_equal(accurate_consensus, obs.name)
  end

  def test_recalc_error
    login
    # Make recalc throw an error with Observation.find(-1)
    get(:recalc, params: { id: -1 })

    assert_flash_text(/Caught exception/)
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
      assert_redirected_to(action: :list_rss_logs)
      assert_flash_text(/denied|only.*admin/i)

      make_admin("rolf")
      get_with_dump(page, params)
      assert_template(response) # 1
    end
  end

  def test_email_features
    page = :email_features
    params = { feature_email: { content: "test" } }

    logout
    post(page, params: params)
    assert_redirected_to(controller: :account, action: :login)

    login("rolf")
    post(page, params: params)
    assert_redirected_to(controller: :observer, action: :list_rss_logs)
    assert_flash_text(/denied|only.*admin/i)

    make_admin("rolf")
    post_with_dump(page, params)
    assert_redirected_to(controller: :observer, action: :users_by_name)
  end

  def test_send_commercial_inquiry
    image = images(:commercial_inquiry_image)
    params = {
      id: image.id,
      commercial_inquiry: {
        content: "Testing commercial_inquiry"
      }
    }
    post_requires_login(:commercial_inquiry, params)
    assert_redirected_to(controller: :image, action: :show_image, id: image.id)
  end

  def test_send_ask_observation_question
    obs = observations(:minimal_unknown_obs)
    params = {
      id: obs.id,
      question: {
        content: "Testing question"
      }
    }
    post_requires_login(:ask_observation_question, params)
    assert_redirected_to(action: :show_observation)
    assert_flash_text(:runtime_ask_observation_question_success.t)
  end

  def test_send_ask_user_question
    user = mary
    params = {
      id: user.id,
      email: {
        subject: "Email subject",
        content: "Email content"
      }
    }
    post_requires_login(:ask_user_question, params)
    assert_redirected_to(action: :show_user, id: user.id)
    assert_flash_text(:runtime_ask_user_question_success.t)
  end

  def test_email_merge_request
    name1 = Name.all.sample
    name2 = Name.all.sample
    params = {
      type: :Name,
      old_id: name1.id,
      new_id: name2.id
    }

    get(:email_merge_request, params: params)
    assert_response(:redirect)

    login("rolf")
    get(:email_merge_request, params: params.except(:type))
    assert_response(:redirect)
    get(:email_merge_request, params: params.except(:old_id))
    assert_response(:redirect)
    get(:email_merge_request, params: params.except(:new_id))
    assert_response(:redirect)
    get(:email_merge_request, params: params.merge(type: :Bogus))
    assert_response(:redirect)
    get(:email_merge_request, params: params.merge(old_id: -123))
    assert_response(:redirect)
    get(:email_merge_request, params: params.merge(new_id: -456))
    assert_response(:redirect)

    get_with_dump(:email_merge_request, params)
    assert_response(:success)
    assert_names_equal(name1, assigns(:old_obj))
    assert_names_equal(name2, assigns(:new_obj))
    url = "email_merge_request?new_id=#{name2.id}&old_id=#{name1.id}&type=Name"
    assert_select("form[action*='#{url}']", count: 1)
  end

  def test_email_merge_request_post
    email_count = ActionMailer::Base.deliveries.count
    name1 = Name.all.sample
    name2 = Name.all.sample
    params = {
      type: :Name,
      old_id: name1.id,
      new_id: name2.id,
      notes: "SHAZAM"
    }

    post(:email_merge_request, params: params)
    assert_response(:redirect)
    assert_equal(email_count, ActionMailer::Base.deliveries.count)

    login("rolf")
    post(:email_merge_request, params: params)
    assert_response(:redirect)
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    assert_match(/SHAZAM/, ActionMailer::Base.deliveries.last.to_s)
  end

  def test_show_notifications
    # First, create a naming notification email, making sure it has a template,
    # and making sure the person requesting the notifcation is not the same
    # person who created the underlying observation (otherwise nothing happens).
    note = notifications(:coprinus_comatus_notification)
    note.user = mary
    note.note_template = "blah!"
    assert(note.save)
    QueuedEmail.queue_emails(true)
    QueuedEmail::NameTracking.create_email(
      note, namings(:coprinus_comatus_other_naming)
    )

    # Now we can be sure show_notifications is supposed to actually show a
    # non-empty list, and thus that this test is meaningful.
    requires_login(:show_notifications,
                   id: observations(:coprinus_comatus_obs).id)
    assert_template(:show_notifications)
    QueuedEmail.queue_emails(false)
  end

  def test_author_request
    id = name_descriptions(:coprinus_comatus_desc).id
    requires_login(:author_request, id: id, type: :name_description)
    assert_form_action(action: :author_request, id: id,
                       type: :name_description)

    id = location_descriptions(:albion_desc).id
    requires_login(:author_request, id: id, type: :location_description)
    assert_form_action(action: :author_request, id: id,
                       type: :location_description)

    params = {
      id: name_descriptions(:coprinus_comatus_desc).id,
      type: :name_description,
      email: {
        subject: "Author request subject",
        message: "Message for authors"
      }
    }
    post_requires_login(:author_request, params)
    assert_redirected_to(
      controller: :name,
      action: :show_name_description,
      id: name_descriptions(:coprinus_comatus_desc).id
    )
    assert_flash_text(:request_success.t)

    params = {
      id: location_descriptions(:albion_desc).id,
      type: :location_description,
      email: {
        subject: "Author request subject",
        message: "Message for authors"
      }
    }
    post_requires_login(:author_request, params)
    assert_redirected_to(controller: :location,
                         action: :show_location_description,
                         id: location_descriptions(:albion_desc).id)
    assert_flash_text(:request_success.t)
  end

  def test_review_authors_locations
    desc = location_descriptions(:albion_desc)
    params = { id: desc.id, type: "LocationDescription" }
    desc.authors.clear
    assert_user_list_equal([], desc.reload.authors)

    # Make sure it lets Rolf and only Rolf see this page.
    assert_not(mary.in_group?("reviewers"))
    assert(rolf.in_group?("reviewers"))
    requires_user(:review_authors,
                  [{ controller: :location,
                     action: :show_location,
                     id: desc.location_id }],
                  params)
    assert_template(:review_authors)

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(rolf)
    rolf.reload
    assert_not(rolf.in_group?("reviewers"))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, params: params)
    assert_redirected_to(controller: :location,
                         action: :show_location,
                         id: locations(:albion).id)

    # Make Rolf an author.
    desc.add_author(rolf)
    desc.save
    desc.reload
    assert_user_list_equal([rolf], desc.authors)

    # Rolf should be able to do it now.
    get(:review_authors, params: params)
    assert_template(:review_authors)

    # Rolf giveth with one hand...
    post(:review_authors, params: params.merge(add: mary.id))
    assert_template(:review_authors)
    desc.reload
    assert_user_list_equal([mary, rolf], desc.authors, :sort)

    # ...and taketh with the other.
    post(:review_authors, params: params.merge(remove: mary.id))
    assert_template(:review_authors)
    desc.reload
    assert_user_list_equal([rolf], desc.authors)
  end

  def test_review_authors_name
    name = names(:peltigera)
    desc = name.description

    params = { id: desc.id, type: "NameDescription" }

    # Make sure it lets reviewers get to page.
    requires_login(:review_authors, params)
    assert_template(:review_authors)

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(rolf)
    assert_not(rolf.reload.in_group?("reviewers"))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, params: params)
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)

    # Make Rolf an author.
    desc.add_author(rolf)
    assert_user_list_equal([rolf], desc.reload.authors)

    # Rolf should be able to do it again now.
    get(:review_authors, params: params)
    assert_template(:review_authors)

    # Rolf giveth with one hand...
    post(:review_authors, params: params.merge(add: mary.id))
    assert_template(:review_authors)
    assert_user_list_equal([mary, rolf], desc.reload.authors, :sort)

    # ...and taketh with the other.
    post(:review_authors, params: params.merge(remove: mary.id))
    assert_template(:review_authors)
    assert_user_list_equal([rolf], desc.reload.authors)
  end

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
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)
    assert_equal(false, name.reload.ok_for_export)

    get("set_export_status", params: params.merge(value: "1"))
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)
    assert_equal(true, name.reload.ok_for_export)

    get("set_export_status", params: params.merge(value: "1", return: true))
    assert_redirected_to("/")
  end

  def test_original_filename_visibility
    login("mary")
    obs_id = observations(:agaricus_campestris_obs).id

    rolf.keep_filenames = :toss
    rolf.save
    get(:show_observation, params: { id: obs_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_but_hide
    rolf.save
    get(:show_observation, params: { id: obs_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_and_show
    rolf.save
    get(:show_observation, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))

    login("rolf") # owner

    rolf.keep_filenames = :toss
    rolf.save
    get(:show_observation, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_but_hide
    rolf.save
    get(:show_observation, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_and_show
    rolf.save
    get(:show_observation, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))
  end

  # ------------------------------
  #  Test creating observations.
  # ------------------------------

  # Test "get" side of create_observation.
  def test_create_observation
    requires_login(:create_observation)
    assert_form_action(action: :create_observation, approved_name: "")
    assert_input_value(:collection_number_name,
                       users(:rolf).legal_name)
    assert_input_value(:collection_number_number, "")
    assert_input_value(:herbarium_record_herbarium_name,
                       users(:rolf).preferred_herbarium_name)
    assert_input_value(:herbarium_record_herbarium_id, "")
    assert_true(@response.body.include?("Albion, Mendocino Co., California"))
    users(:rolf).update(location_format: :scientific)
    get(:create_observation)
    assert_true(@response.body.include?("California, Mendocino Co., Albion"))
  end

  def test_create_observation_with_unrecognized_name
    text_name = "Elfin saddle"
    params = { name: { name: text_name },
               user: rolf,
               where: locations.first.name }
    post_requires_login(:create_observation, params)

    assert_select("div[id='name_messages']",
                  /MO does not recognize the name.*#{text_name}/)
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

  def test_create_observation_herbarium_record_already_used
    record = herbarium_records(:field_museum_record)
    user = dick
    assert_not(
      record.can_edit?(user),
      "Test needs different fixture: herbarim_record not editable by user"
    )
    old_record_obs_count = record.observations.count
    included_in_flash = :create_herbarium_record_already_used_by_someone_else.t(
      herbarium_name: record.herbarium.name
    )

    generic_construct_observation(
      { observation: { specimen: "1" },
        herbarium_record: {
          herbarium_name: record.herbarium.name,
          herbarium_id: record.accession_number
        },
        name: { name: "Coprinus comatus" } },
      1, 1, 0, dick
    )
    obs = assigns(:observation)

    assert(obs.specimen)
    assert_flash_text(/#{included_in_flash}/)
    assert(obs.herbarium_records.count.zero?)
    assert_equal(old_record_obs_count, record.observations.count)
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
    assert_equal("2.03659",
                 format("%<vote_cache>.5f", vote_cache: obs.vote_cache))
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
      { name: { name: "Another new-name  " },
        approved_name: "Another new-name  " },
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
                                    observation: { place_name: "Unknown",
                                                   lat: lat, long: long },
                                    name: { name: "Unknown" },
                                    approved_where: "Unknown"
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
                                    observation: { place_name: "Unknown",
                                                   lat: lat2, long: long2 },
                                    name: { name: "Unknown" },
                                    approved_where: "Unknown"
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
    # No longer accepts "Earth" until you approve it.
    generic_construct_observation({
                                    observation: { place_name: "Earth",
                                                   lat: "", long: "" },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
  end

  def test_create_observation_with_various_altitude_formats
    [
      ["500",     500],
      ["500m",    500],
      ["500 ft.", 152],
      [" 500' ", 152]
    ].each do |input, output|
      where = "California, USA"
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
      { observation: { place_name: "California, USA", lat: "", long: "" },
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
      observation: { place_name: "California, USA", lat: "", long: "" },
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

    post_requires_login(:create_observation, params)
    name = Name.last

    # assert_redirected_to(action: :show_observation)
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
      { observation: { place_name: "Unknown", lat: "", long: "" },
        name: { name: "Morchella elata group" },
        approved_name: "Morchella elata group",
        approved_where: "Unknown" },
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
                                    observation: { place_name: "Unknown" },
                                    name: { name: "Cladina pictum" },
                                    approved_name: "Cladina pictum",
                                    approved_where: "Unknown"
                                  }, 1, 1, 1, roy)

    name = Name.last
    assert_equal("Cladina pictum", name.text_name)
    assert_true(name.deprecated)
  end

  def assert_no_dubious_reasons
    assert_empty(@controller.instance_variable_get("@dubious_where_reasons"))
  end

  def assert_dubious_reasons_present
    assert_not_empty(
      @controller.instance_variable_get("@dubious_where_reasons")
    )
  end

  def test_construct_observation_dubious_place_names_1
    # Name reversed, not dubious, and since it has no suggestions of
    # similar names, it will go ahead and create it.
    where = "USA, Massachusetts, Reversed"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0, roy)
    assert_no_dubious_reasons
  end

  def test_construct_observation_dubious_place_names_2
    # Missing space.
    where = "Reversible, Massachusetts,USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    assert_dubious_reasons_present
  end

  def test_construct_observation_dubious_place_names_3
    # This missing space is auto-corrected when the name is reversed.
    # No suggestions of similar names, so it creates it.
    where = "USA,Massachusetts, Reversible"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0, roy)
    assert_no_dubious_reasons
  end

  def test_construct_observation_dubious_place_names_4
    # Bogus country is dubious.
    where = "Bogus, Massachusetts, UAS"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    assert_dubious_reasons_present
  end

  def test_construct_observation_dubious_place_names_5
    # Bogus country is dubious.
    where = "UAS, Massachusetts, Bogus"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0, roy)
    assert_dubious_reasons_present
  end

  def test_construct_observation_dubious_place_names_6
    # Bogus state is dubious.
    where = "Bad State Name, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    assert_dubious_reasons_present
  end

  def test_construct_observation_dubious_place_names_7
    # Bogus state is dubious.
    where = "USA, Bad State Name"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0, roy)
    assert_dubious_reasons_present
  end

  def test_construct_observation_dubious_place_names_8
    # County is now allowed, so this is not dubious, but it will
    # suggest the existing name which has no county.
    where = "Burbank, Los Angeles Co., California, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    assert_no_dubious_reasons
  end

  def test_construct_observation_dubious_place_names_9
    # County is now allowed, so this is not dubious, but it will
    # suggest the existing name which has no county.
    where = "USA, California, Los Angeles Co., Burbank"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0, roy)
    assert_no_dubious_reasons
  end

  def test_construct_observation_dubious_place_names_10
    # County is now allowed, so this is not dubious, and since there
    # are no similar names, it will go ahead and create it.
    where = "Falmouth, Barnstable Co., Massachusetts, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0)
    assert_no_dubious_reasons
  end

  def test_construct_observation_dubious_place_names_11
    # County is now allowed, so this is not dubious, and since there
    # are no similar names, it will go ahead and create it.
    where = "USA, Massachusetts, Barnstable Co., Falmouth"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0, roy)
    assert_no_dubious_reasons
  end

  def test_construct_observation_dubious_place_names_12
    # "County" should be abbreviated, so this is dubious.
    where = "Some County, Ohio, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    assert_dubious_reasons_present
  end

  def test_construct_observation_dubious_place_names_13
    # "Rd" should have period, so this is dubious.
    where = "Old Rd, Ohio, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 0, 0, 0)
    assert_dubious_reasons_present
  end

  def test_construct_observation_dubious_place_names_14
    # "Rd." is correct, so this is not dubious, and since there are
    # no similar locations, it should create this.
    where = "Old Rd., Ohio, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0)
    assert_no_dubious_reasons
  end

  def test_construct_observation_dubious_place_names_15
    # Adding "near" and "Southern" are fair, so not dubious, and since
    # it the existing "Burbank, California, USA" is so different, it
    # won't suggest it, and thus it should create this.
    where = "near Burbank, Southern California, USA"
    generic_construct_observation({
                                    observation: { place_name: where },
                                    name: { name: "Unknown" }
                                  }, 1, 0, 0)
    assert_no_dubious_reasons
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
    post(:create_observation, params: params)
    # assert_template(action: expected_page)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = "Agaricus sp"
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = "Agaricus sp."
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    # Can we create observation with genus and add author?
    params[:name][:name] = "Agaricus Author"
    params[:approved_name] = "Agaricus Author"
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal("Agaricus Author", agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = "Agaricus"
    agaricus.save

    params[:name][:name] = "Agaricus sp Author"
    params[:approved_name] = "Agaricus sp Author"
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal("Agaricus Author", agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = "Agaricus"
    agaricus.save

    params[:name][:name] = "Agaricus sp. Author"
    params[:approved_name] = "Agaricus sp. Author"
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal("Agaricus Author", agaricus.reload.search_name)

    # Can we create observation with genus specifying author?
    params[:name][:name] = "Agaricus Author"
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = "Agaricus sp Author"
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = "Agaricus sp. Author"
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus?
    psalliota = names(:psalliota)
    params[:name][:name] = "Psalliota"
    params[:approved_name] = "Psalliota"
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = "Psalliota sp"
    params[:approved_name] = "Psalliota sp"
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = "Psalliota sp."
    params[:approved_name] = "Psalliota sp."
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus, adding author?
    params[:name][:name] = "Psalliota Author"
    params[:approved_name] = "Psalliota Author"
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal("Psalliota Author", psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = "Psalliota"
    psalliota.save

    params[:name][:name] = "Psalliota sp Author"
    params[:approved_name] = "Psalliota sp Author"
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal("Psalliota Author", psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = "Psalliota"
    psalliota.save

    params[:name][:name] = "Psalliota sp. Author"
    params[:approved_name] = "Psalliota sp. Author"
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal("Psalliota Author", psalliota.reload.search_name)

    # Can we create new quoted genus?
    params[:name][:name] = '"One"'
    params[:approved_name] = '"One"'
    post(:create_observation, params: params)
    # assert_template(controller: :observer, action: expected_page)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One"', assigns(:observation).name.search_name)

    params[:name][:name] = '"Two" sp'
    params[:approved_name] = '"Two" sp'
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"Two"', assigns(:observation).name.text_name)
    assert_equal('"Two"', assigns(:observation).name.search_name)

    params[:name][:name] = '"Three" sp.'
    params[:approved_name] = '"Three" sp.'
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"Three"', assigns(:observation).name.text_name)
    assert_equal('"Three"', assigns(:observation).name.search_name)

    params[:name][:name] = '"One"'
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp'
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp.'
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)

    # Can we create species under the quoted genus?
    params[:name][:name] = '"One" foo'
    params[:approved_name] = '"One" foo'
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One" foo', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" "bar"'
    params[:approved_name] = '"One" "bar"'
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One" "bar"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" Author'
    params[:approved_name] = '"One" Author'
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp Author'
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp. Author'
    params[:approved_name] = nil
    post(:create_observation, params: params)
    assert_redirected_to(/#{expected_page}/)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" Author', assigns(:observation).name.search_name)
  end

  def test_create_observation_strip_images
    login("rolf")
    loc = locations(:burbank)

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
      :create_observation,
      params: {
        observation: {
          when: Time.zone.now,
          place_name: loc.name,
          lat: loc.center.first,
          long: loc.center.last,
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
      }
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

  def test_create_observation_pending_naming_notification
    params = {
      observation: {
        when: Time.zone.now,
        place_name: locations(:albion).name,
        specimen: "0",
        thumb_image_id: "0"
      },
      name: {},
      vote: { value: "3" }
    }
    login("rolf")

    ObserverController.any_instance.stubs(:unshown_notifications?).returns(true)
    post(:create_observation, params: params)

    assert_redirected_to(/#{observer_show_notifications_path}/)
  end

  # ----------------------------------------------------------------
  #  Test edit_observation, both "get" and "post".
  # ----------------------------------------------------------------

  # (Sorry, these used to all be edit/update_observation, now they're
  # confused because of the naming stuff.)
  def test_edit_observation_get
    obs = observations(:coprinus_comatus_obs)
    assert_equal("rolf", obs.user.login)
    params = { id: obs.id.to_s }
    requires_user(:edit_observation,
                  [{ controller: :observer, action: :show_observation }],
                  params)

    assert_form_action(action: :edit_observation, id: obs.id.to_s)

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
    post_requires_user(:edit_observation,
                       [{ controller: :observer, action: :show_observation }],
                       params,
                       "mary")
    # assert_redirected_to(controller: :location, action: :create_location)
    assert_redirected_to(/#{ url_for(controller: :location,
                                     action: :create_location) }/)
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
      :edit_observation,
      [{ controller: :observer, action: :show_observation }],
      params,
      "mary"
    )
    # assert_redirected_to(controller: :location, action: :create_location)
    assert_redirected_to(%r{/location/create_location})
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
      :edit_observation,
      [{ controller: :observer, action: :show_observation }],
      params,
      "mary"
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
    post(:edit_observation, params: params)
    assert_redirected_to(action: :show_observation)
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
    post(:edit_observation, params: params)

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
      :edit_observation,
      params: {
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

  def test_edit_observation_save_failure
    obs = observations(:minimal_unknown_obs)
    params = {
      id: obs.id.to_s,
      observation: {
        notes: { other: "new notes" },
        place_name: obs.where,
        "when(1i)" => "2006",
        "when(2i)" => "05",
        "when(3i)" => "11",
        specimen: obs.specimen,
        thumb_image_id: obs.thumb_image_id
      },
      log_change: { checked: "0" }
    }

    login(obs.user.name)
    Observation.any_instance.stubs(:save).returns(false)
    assert_no_difference(
      "Observation.count", "An Observation should not be created"
    ) do
      post(:edit_observation, params: params)
    end

    assert_flash_text(/#{:runtime_no_save.l(type: "observation")}/)
    assert_response(:success, "Edit form should be reloaded")
  end

  def test_edit_observation_image_save_failure
    obs = observations(:detailed_unknown_obs)
    # more detailed location to avoid location flash warning and redirection
    location = locations(:point_reyes)
    obs.update(location: location)
    img = obs.images.first
    img_notes = img.notes

    params = {
      id: obs.id.to_s,
      observation: {
        notes: obs.notes,
        place_name: obs.where,
        "when(1i)" => obs.when.strftime("%Y"),
        "when(2i)" => obs.when.strftime("%m"),
        "when(3i)" => obs.when.strftime("%d"),
        specimen: obs.specimen,
        thumb_image_id: obs.thumb_image_id
      },
      good_images: "#{img.id} #{images(:turned_over_image).id}",
      good_image: {
        img.id.to_s => {
          notes: "change something to force image to be saved",
          original_name: img.original_name,
          copyright_holder: img.copyright_holder,
          "when(1i)" => img.when.strftime("%Y"),
          "when(2i)" => img.when.strftime("%m"),
          "when(3i)" => img.when.strftime("%d"),
          license_id: img.license_id
        }
      },
      log_change: { checked: "0" }
    }

    login(obs.user.name)
    Image.any_instance.stubs(:save).returns(false)
    post(:edit_observation, params: params)

    assert_redirected_to(/#{obs.id}$/)
    assert_equal(img_notes, img.reload.notes)
  end

  # --------------------------------------------------------------------
  #  Test notes with template create_observation, and edit_observation,
  #  both "get" and "post".
  # --------------------------------------------------------------------

  # Prove that create_observation renders note fields with template keys first,
  # in the order listed in the template
  def test_create_observation_with_notes_template_get
    user = users(:notes_templater)
    login(user.login)
    get(:create_observation)

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
    post(:create_observation, params: params)

    assert_equal(o_size + 1, Observation.count)
    obs = Observation.last.reload
    assert_redirected_to(action: :show_observation, id: obs.id)
    assert_equal(expected_notes, obs.notes)
  end

  # Prove that edit_observation has correct note fields and content:
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
    get(:edit_observation, params: params)
    assert_page_has_correct_notes_areas(
      expect_areas: { Cap: "", Nearby_trees: "", odor: "",
                      Observation.other_notes_key => "" }
    )

    obs         = observations(:templater_other_notes_obs)
    params[:id] = obs.id
    params[:observation][:notes] = obs.notes
    get(:edit_observation, params: params)
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
    post(:edit_observation, params: params)

    assert_redirected_to(action: :show_observation, id: obs.id)
    assert_equal(notes, obs.reload.notes)
  end

  # -----------------------------------
  #  Test extended observation forms.
  # -----------------------------------

  def test_javascripty_name_reasons
    login("rolf")

    # If javascript isn't enabled, then checkbox isn't required.
    post(:create_observation,
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
    post(:create_observation,
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
        :create_observation,
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
        :create_observation,
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
      :create_observation,
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
    get(:create_observation)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)

    login("dick")
    get(:create_observation)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)

    # Should have different default
    # if recently posted observation attached to project.
    obs = Observation.create!
    @proj2.add_observation(obs)
    get(:create_observation)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :checked)

    # Make sure it remember state of checks if submit fails.
    post(:create_observation,
         params: {
           name: { name: "Screwy Name" }, # (ensures it will fail)
           project: { "id_#{@proj1.id}" => "0" }
         })
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)
  end

  def test_project_checkboxes_in_edit_observation
    init_for_project_checkbox_tests

    login("rolf")
    get(:edit_observation, params: { id: @obs1.id })
    assert_response(:redirect)
    get(:edit_observation, params: { id: @obs2.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
    post(
      :edit_observation,
      params: {
        id: @obs2.id,
        observation: { place_name: "blah blah blah" },  # (ensures it will fail)
        project: { "id_#{@proj1.id}" => "1" }
      }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    post(:edit_observation,
         params: {
           id: @obs2.id,
           project: { "id_#{@proj1.id}" => "1" }
         })
    assert_response(:redirect)
    assert_obj_list_equal([@proj1], @obs2.reload.projects)
    assert_obj_list_equal([@proj1], @img2.reload.projects)

    login("mary")
    get(:edit_observation, params: { id: @obs2.id })
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    get(:edit_observation, params: { id: @obs1.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :checked)
    post(
      :edit_observation,
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
      :edit_observation,
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
    get(:edit_observation, params: { id: @obs2.id })
    assert_response(:redirect)
    get(:edit_observation, params: { id: @obs1.id })
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
    get(:create_observation)
    assert_list_checks(@spl1.id => :unchecked, @spl2.id => :no_field)

    login("mary")
    get(:create_observation)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)

    login("katrina")
    get(:create_observation)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :no_field)

    # Dick is on project that owns @spl2.
    login("dick")
    get(:create_observation)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)

    # Should have different default
    # if recently posted observation attached to project.
    obs = Observation.create!
    @spl1.add_observation(obs) # (shouldn't affect anything for create)
    @spl2.add_observation(obs)
    get(:create_observation)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :checked)

    # Make sure it remember state of checks if submit fails.
    post(:create_observation,
         params: {
           name: { name: "Screwy Name" }, # (ensures it will fail)
           list: { "id_#{@spl2.id}" => "0" }
         })
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)
  end

  def test_list_checkboxes_in_edit_observation
    init_for_list_checkbox_tests

    login("rolf")
    get(:edit_observation, params: { id: @obs1.id })
    assert_list_checks(@spl1.id => :unchecked, @spl2.id => :no_field)
    spl_start_length = @spl1.observations.length
    post(
      :edit_observation,
      params: {
        id: @obs1.id,
        observation: { place_name: "blah blah blah" }, # (ensures it will fail)
        list: { "id_#{@spl1.id}" => "1" }
      }
    )
    assert_equal(spl_start_length, @spl1.reload.observations.length)
    assert_list_checks(@spl1.id => :checked, @spl2.id => :no_field)
    post(
      :edit_observation,
      params: {
        id: @obs1.id,
        list: { "id_#{@spl1.id}" => "1" }
      }
    )
    assert_equal(spl_start_length + 1, @spl1.reload.observations.length)
    assert_response(:redirect)
    assert_obj_list_equal([@spl1], @obs1.reload.species_lists)
    get(:edit_observation, params: { id: @obs2.id })
    assert_response(:redirect)

    login("mary")
    get(:edit_observation, params: { id: @obs1.id })
    assert_response(:redirect)
    get(:edit_observation, params: { id: @obs2.id })
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :checked)
    @spl1.add_observation(@obs2)
    get(:edit_observation, params: { id: @obs2.id })
    assert_list_checks(@spl1.id => :checked_but_disabled, @spl2.id => :checked)

    login("dick")
    get(:edit_observation, params: { id: @obs2.id })
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

  def do_loc_test(str: "", gps: [], geo: [], approved: false, succeed: false)
    params = {
      observation: {
        place_name: str.to_s,
        lat: gps[0].to_s,
        long: gps[1].to_s
      },
      country: geo[0].to_s,
      state: geo[1].to_s,
      county: geo[2].to_s,
      city: geo[3].to_s,
      approved_where: approved ? str : "something else"
    }
    login("rolf") unless User.current
    post(:create_observation,
         params: modified_generic_params(params, User.current))
    if succeed
      expect_obs_form_to_succeed
    else
      expect_obs_form_to_fail
    end
  end

  def expect_obs_form_to_succeed
    assert_empty(
      @controller.instance_variable_get("@dubious_where_reasons") +
      @controller.instance_variable_get("@location_suggestion_reasons") +
      @controller.instance_variable_get("@location_suggestions")
    )
    assert_response(:redirect, "expected it to accept this submission")
  end

  def expect_obs_form_to_fail
    assert_response(:success, "expected it to reload the form")
    @reasons = \
      @controller.instance_variable_get("@location_suggestion_reasons")
    @suggestions = @controller.instance_variable_get("@location_suggestions")
    @place_name = @controller.instance_variable_get("@place_name")
  end

  def assert_suggestions_include(loc)
    assert_includes(@suggestions.map(&:name), loc.name)
  end

  # First submit with nothing: no place_name, lat/long or geolocation.
  def test_create_observation_without_location_latlong_or_geolocation
    do_loc_test(str: "")
    assert_includes(@reasons, :form_observations_location_missing.t)
    assert_empty(@suggestions)
    assert_blank(@place_name)
  end

  # Now add lat/long to see if it finds a location which contains it.
  def test_create_observation_with_just_latlong
    loc = locations(:burbank)
    do_loc_test(gps: loc.center)
    assert_includes(@reasons, :form_observations_location_missing.t)
    assert_suggestions_include(loc)
    assert_blank(@place_name)
  end

  # Now add reverse geolocation to make sure it fills in place_name.
  def test_create_observation_with_just_geolocation
    loc = locations(:burbank)
    geolocation = ["USA", "California", "Los Angeles Co.", "Burbank"]
    do_loc_test(geo: geolocation)
    assert_includes(@reasons, :form_observations_location_missing.t)
    assert_suggestions_include(loc)
    assert_equal("Burbank, Los Angeles Co., California, USA", @place_name)
  end

  # Same thing but reverse location order (and explicitly enter "Earth"
  # for the place name to make sure it catches that, too).
  def test_create_observation_with_just_geolocation_reversed
    loc = locations(:burbank)
    geolocation = ["USA", "California", "Los Angeles Co.", "Burbank"]
    users(:rolf).update(location_format: :scientific)
    do_loc_test(str: "Earth", geo: geolocation)
    assert_includes(@reasons, :form_observations_location_missing.t)
    assert_suggestions_include(loc)
    assert_equal("USA, California, Los Angeles Co., Burbank", @place_name)
  end

  # And submit again with "Earth" approved to prove that user can override
  # our whinging.
  def test_create_observation_with_no_location_but_approved
    geolocation = ["USA", "California", "Los Angeles Co.", "Burbank"]
    str = Location.unknown.name
    do_loc_test(str: str, geo: geolocation, approved: true, succeed: true)
  end

  # Submit a point within Burbank, but only list location as "California".
  def test_create_observation_with_inaccurate_location
    loc = locations(:burbank)
    str = "California, USA"
    do_loc_test(str: str, gps: loc.center)
    assert_includes(@reasons, :form_observations_location_inaccurate.t)
    assert_suggestions_include(loc)
    assert_equal(str, @place_name)
  end

  # Submit a point that's not even close to Burbank while listing it
  # erroneously as "Burbank".
  def test_create_observation_with_pin_way_off
    loc = locations(:burbank)
    lat2 = loc.north + (loc.north - loc.south)
    long2 = loc.west - (loc.east - loc.west)
    assert_false(loc.close?(lat2, long2))
    do_loc_test(str: loc.name, gps: [lat2, long2])
    assert_includes(@reasons, :form_observations_location_outside.t)
    # Should at least see that this point is in California!
    assert_suggestions_include(locations(:california))
    assert_equal(loc.name, @place_name)
  end

  # Submit a point that's close but not actually in Burbank (off by 9%),
  # listing it as "Burbank".
  def test_create_observation_with_pin_at_least_close
    loc = locations(:burbank)
    lat2 = loc.north + (loc.north - loc.south) * 0.09
    long2 = loc.west - (loc.east - loc.west) * 0.09
    assert_true(loc.close?(lat2, long2))
    do_loc_test(str: loc.name, gps: [lat2, long2], succeed: true)
  end

  # Try a point within Burbank and actually list it as "Burbank".
  def test_create_observation_with_correct_pin
    loc = locations(:burbank)
    do_loc_test(str: loc.name, gps: loc.center, succeed: true)
  end

  # Submit a location with a county that lacks the county in the database.
  def test_create_observation_bad_location_00
    loc = locations(:burbank)
    assert_equal("Burbank, California, USA", loc.name)
    str = "Burbank, Los Angeles Co., California, USA"
    do_loc_test(str: str)
    assert_includes(@reasons, :form_observations_location_doesnt_exist.t)
    assert_suggestions_include(loc)
    assert_equal(str, @place_name)
  end

  # Approve it and try again.
  def test_create_observation_bad_location_0
    str = "Burbank, Los Angeles Co., California, USA"
    do_loc_test(str: str, approved: true, succeed: true)
  end

  # Submit a location without a county that has a county in the database.
  def test_create_observation_bad_location_1
    loc = locations(:brett_woods)
    assert_equal("Brett Woods, Fairfield Co., Connecticut, USA", loc.name)
    str = "Brett Woods, Connecticut, USA"
    do_loc_test(str: str)
    assert_suggestions_include(loc)
  end

  # Submit an existing location but omitting the country.
  def test_create_observation_bad_location_2
    loc = locations(:brett_woods)
    str = "Brett Woods, CT"
    do_loc_test(str: str)
    assert_suggestions_include(loc)
  end

  # Submit an existing location but with misspelled country.
  def test_create_observation_bad_location_3
    loc = locations(:elgin_co)
    assert_equal("Elgin Co., Ontario, Canada", loc.name)
    str = "Elgin Co., Ontario, KKanada"
    do_loc_test(str: str)
    assert_suggestions_include(loc)
  end

  # Submit an existing location with badly misspelled country, but google
  # provides a correct country.
  def test_create_observation_bad_location_4
    loc = locations(:elgin_co)
    str = "Elgin Co., Ontario, Oops"
    do_loc_test(str: str, geo: ["Canada"])
    assert_suggestions_include(loc)
  end

  # Submit an existing location but with misspelled country and abbreviated
  # state.
  def test_create_observation_bad_location_5
    loc = locations(:elgin_co)
    str = "Elgin Co., ON, Kanada"
    do_loc_test(str: str)
    assert_suggestions_include(loc)
  end

  # Submit an existing location with misspelled state in country without
  # states.
  def test_create_observation_bad_location_6
    loc = locations(:birgu)
    assert_equal("Birgu, Malta", loc.name)
    do_loc_test(str: "Bigru, Malta")
    assert_suggestions_include(loc)
  end

  # Submit an existing location with misspelled state in country with states.
  def test_create_observation_bad_location_7
    loc = locations(:burbank)
    assert_equal("Burbank, California, USA", loc.name)
    do_loc_test(str: "Burbank, Calfiornia, USA")
    assert_suggestions_include(loc)
  end

  # Submit an existing location with badly misspelled state in country with
  # states, but google provides correct state.
  def test_create_observation_bad_location_8
    loc = locations(:burbank)
    do_loc_test(str: "Burbank, Cali, USA",
                geo: ["USA", "California", "Los Angeles Co."])
    assert_suggestions_include(loc)
  end

  # Submit an existing location that has county misspelled.
  def test_create_observation_bad_location_9
    loc = locations(:brett_woods)
    assert_equal("Brett Woods, Fairfield Co., Connecticut, USA", loc.name)
    str = "Brett Woods, Connecticut, USA"
    do_loc_test(str: str)
    assert_suggestions_include(loc)
  end

  # Submit an existing location that has city misspelled.
  def test_create_observation_bad_location_10
    loc = locations(:brett_woods)
    str = "Brett's Woods, CT"
    do_loc_test(str: str)
    assert_suggestions_include(loc)
  end

  # Submit an existing location omitting a name below county but above
  # the final term.
  def test_create_observation_bad_location_11
    loc = locations(:mitrula_marsh)
    assert_equal(
      '"Mitrula Marsh", Sand Lake, Bassetts, Yuba Co., California, USA',
      loc.name
    )
    do_loc_test(str: "Mitrula Marsh, Bassetts, CA")
    assert_suggestions_include(loc)
  end

  # Submit something totally wonky, but google gives something we can work
  # with.
  def test_create_observation_bad_location_12
    loc = locations(:burbank)
    do_loc_test(str: "Burbank",
                geo: ["USA", "California", "Los Angeles Co.", "Burbank"])
    assert_suggestions_include(loc)
  end

  # Submit something totally wonky and google is no help.
  def test_create_observation_bad_location_13
    do_loc_test(str: "Willy Wonka's Toy Factory",
                geo: %w[unknown unknown unknown])
    assert_empty(@suggestions)
  end

  def test_create_observation_choosing_location_suggestion
    user = rolf
    login(user.login)
    loc = locations(:burbank)
    params = {
      observation: { place_name: "whatever" },
      approved_where: "something else",
      location_suggestions: { name: loc.name }
    }
    post(:create_observation, params: modified_generic_params(params, user))
    assert_response(:redirect, "expected this to submit successfully")
    obs = Observation.last
    assert_objs_equal(loc, obs.location)
  end

  # User tries to remove the place name, but google comes to the rescue.
  def test_edit_observation_try_to_remove_location
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)
    loc = locations(:gualala)
    params = {
      id: obs.id.to_s,
      observation: { place_name: Location.unknown.name },
      country: "USA",
      state: "California",
      county: "Mendocino Co.",
      city: "Gualala"
    }
    post(:edit_observation, params: params)
    expect_obs_form_to_fail
    assert_includes(@reasons, :form_observations_location_missing.t)
    assert_suggestions_include(loc)
    assert_equal("Gualala, Mendocino Co., California, USA", @place_name)
  end

  # User tries to change place name to something less accurate.
  def test_edit_observation_try_to_change_to_less_accurate
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)
    loc = locations(:burbank)
    lat, long = loc.center
    params = {
      id: obs.id.to_s,
      observation: { place_name: "California, USA", lat: lat, long: long }
    }
    post(:edit_observation, params: params)
    expect_obs_form_to_fail
    assert_includes(@reasons, :form_observations_location_inaccurate.t)
    assert_suggestions_include(loc)
    assert_equal("California, USA", @place_name)
  end

  # User tries to change place name to something screwy that we can correct.
  def test_edit_observation_try_to_change_location_to_something_screwy
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)
    loc = locations(:brett_woods)
    str = "Brett's Woods, CT"
    params = {
      id: obs.id.to_s,
      observation: { place_name: str }
    }
    post(:edit_observation, params: params)
    expect_obs_form_to_fail
    assert_includes(@reasons, :form_observations_location_doesnt_exist.t)
    assert_suggestions_include(loc)
    assert_equal(str, @place_name)
  end

  # User moves the pin way outside of chosen location.
  def test_edit_observation_try_to_move_pin_outside_of_location
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)
    loc = obs.reload.location
    lat = loc.south - (loc.north - loc.south) * 0.5
    long = loc.east + (loc.east - loc.west) * 0.5
    params = {
      id: obs.id.to_s,
      observation: { lat: lat, long: long }
    }
    post(:edit_observation, params: params)
    expect_obs_form_to_fail
    assert_includes(@reasons, :form_observations_location_outside.t)
    assert_suggestions_include(locations(:california))
    assert_equal(loc.name, @place_name)
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  def test_interest_in_show_observation
    login("rolf")
    minimal_unknown = observations(:minimal_unknown_obs)

    # No interest in this observation yet.
    #
    # <img[^>]+watch\d*.png[^>]+>[\w\s]*
    get(:show_observation, params: { id: minimal_unknown.id })
    assert_response(:success)
    assert_image_link_in_html(
      /watch\d*.png/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 1
    )
    assert_image_link_in_html(
      /ignore\d*.png/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: -1
    )

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.create(target: minimal_unknown, user: rolf, state: true)
    get(:show_observation, params: { id: minimal_unknown.id })
    assert_response(:success)
    assert_image_link_in_html(
      /halfopen\d*.png/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 0
    )
    assert_image_link_in_html(
      /ignore\d*.png/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: -1
    )

    # Destroy that interest, create new one with interest off.
    Interest.where(user_id: rolf.id).last.destroy
    Interest.create(target: minimal_unknown, user: rolf, state: false)
    get(:show_observation, params: { id: minimal_unknown.id })
    assert_response(:success)
    assert_image_link_in_html(
      /halfopen\d*.png/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 0
    )
    assert_image_link_in_html(
      /watch\d*.png/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 1
    )
  end

  # ----------------------------
  #  Lookup's.
  #  These are links like /lookup_name/Amanita+muscaria
  #  They can be created by the Textile Sandbox, and should always redirect
  #  to the appropriate model.
  # /lookup_accepted_name is intended for use by other web sites
  # ----------------------------

  def test_lookup_comment
    c_id = comments(:minimal_unknown_obs_comment_1).id
    get(:lookup_comment, params: { id: c_id })
    assert_redirected_to(controller: :comment, action: :show_comment, id: c_id)
    get(:lookup_comment, params: { id: 10_000 })
    assert_redirected_to(controller: :comment, action: :index_comment)
    assert_flash_error
  end

  def test_lookup_image
    i_id = images(:in_situ_image).id
    get(:lookup_image, params: { id: i_id })
    assert_redirected_to(controller: :image, action: :show_image, id: i_id)
    get(:lookup_image, params: { id: 10_000 })
    assert_redirected_to(controller: :image, action: :index_image)
    assert_flash_error
  end

  def test_lookup_location
    l_id = locations(:albion).id
    get(:lookup_location, params: { id: l_id })
    assert_redirected_to(controller: :location,
                         action: :show_location, id: l_id)
    get(:lookup_location, params: { id: "Burbank, California" })
    assert_redirected_to(controller: :location, action: :show_location,
                         id: locations(:burbank).id)
    get(:lookup_location, params: { id: "California, Burbank" })
    assert_redirected_to(controller: :location, action: :show_location,
                         id: locations(:burbank).id)
    get(:lookup_location, params: { id: "Zyzyx, Califonria" })
    assert_redirected_to(controller: :location, action: :index_location)
    assert_flash_error
    get(:lookup_location, params: { id: "California" })
    # assert_redirected_to(controller: :location, action: :index_location)
    assert_redirected_to(%r{/location/index_location})
    assert_flash_warning
  end

  def test_lookup_accepted_name
    get(:lookup_accepted_name,
        params: { id: names(:lactarius_subalpinus).text_name })
    assert_redirected_to(controller: :name, action: :show_name,
                         id: names(:lactarius_alpinus))
  end

  def test_lookup_name
    n_id = names(:fungi).id
    get(:lookup_name, params: { id: n_id })
    assert_redirected_to(controller: :name, action: :show_name, id: n_id)

    get(:lookup_name, params: { id: names(:coprinus_comatus).id })
    assert_redirected_to(%r{/name/show_name/#{names(:coprinus_comatus).id}})

    get(:lookup_name, params: { id: "Agaricus campestris" })
    assert_redirected_to(controller: :name, action: :show_name,
                         id: names(:agaricus_campestris).id)

    get(:lookup_name, params: { id: "Agaricus newname" })
    assert_redirected_to(controller: :name, action: :index_name)
    assert_flash_error

    get(:lookup_name, params: { id: "Amanita baccata sensu Borealis" })
    assert_redirected_to(controller: :name, action: :show_name,
                         id: names(:amanita_baccata_borealis).id)

    get(:lookup_name, params: { id: "Amanita baccata" })
    assert_redirected_to(%r{/name/index_name})
    assert_flash_warning

    get(:lookup_name, params: { id: "Agaricus campestris L." })
    assert_redirected_to(controller: :name, action: :show_name,
                         id: names(:agaricus_campestris).id)

    get(:lookup_name, params: { id: "Agaricus campestris Linn." })
    assert_redirected_to(controller: :name, action: :show_name,
                         id: names(:agaricus_campestris).id)

    # Prove that when there are no hits and exactly one spelling suggestion,
    # it gives a flash warning and shows the page for the suggestion.
    get(:lookup_name, params: { id: "Fungia" })
    assert_flash_text(:runtime_suggest_one_alternate.t(type: :name,
                                                       match: "Fungia"))
    assert_redirected_to(controller: :name, action: :show_name,
                         id: names(:fungi).id)

    # Prove that when there are no hits and >1 spelling suggestion,
    # it flashes a warning and shows the name index
    get(:lookup_name, params: { id: "Verpab" })
    assert_flash_text(:runtime_suggest_multiple_alternates.t(type: :name,
                                                             match: "Verpab"))
    assert_redirected_to(%r{/name/index_name})

    # Prove that lookup_name adds flash message when it hits an error,
    # stubbing a method called by lookup_name in order to provoke an error.
    ObserverController.any_instance.stubs(:fix_name_matches).
      raises(RuntimeError)
    get(:lookup_name, params: { id: names(:fungi).text_name })
    assert_flash_text("RuntimeError")
  end

  def test_lookup_observation
    get(:lookup_observation,
        params: { id: observations(:minimal_unknown_obs).id })
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: observations(:minimal_unknown_obs).id)
  end

  def test_lookup_project
    p_id = projects(:eol_project).id
    get(:lookup_project, params: { id: p_id })
    assert_redirected_to(controller: :project, action: :show_project, id: p_id)
    get(:lookup_project, params: { id: "Bolete" })
    assert_redirected_to(controller: :project, action: :show_project,
                         id: projects(:bolete_project).id)
    get(:lookup_project, params: { id: "Bogus" })
    assert_redirected_to(controller: :project, action: :index_project)
    assert_flash_error
    get(:lookup_project, params: { id: "project" })
    assert_redirected_to(%r{/project/index_project})
    assert_flash_warning
  end

  def test_lookup_species_list
    sl_id = species_lists(:first_species_list).id
    get(:lookup_species_list, params: { id: sl_id })
    assert_redirected_to(controller: :species_list, action: :show_species_list,
                         id: sl_id)
    get(:lookup_species_list, params: { id: "Mysteries" })
    assert_redirected_to(controller: :species_list, action: :show_species_list,
                         id: species_lists(:unknown_species_list).id)
    get(:lookup_species_list, params: { id: "species list" })
    assert_redirected_to(%r{/species_list/index_species_list})
    assert_flash_warning
    get(:lookup_species_list, params: { id: "Flibbertygibbets" })
    assert_redirected_to(controller: :species_list, action: :index_species_list)
    assert_flash_error
  end

  def test_lookup_user
    get(:lookup_user, params: { id: rolf.id })
    assert_redirected_to(controller: :observer, action: :show_user, id: rolf.id)
    get(:lookup_user, params: { id: "mary" })
    assert_redirected_to(controller: :observer, action: :show_user, id: mary.id)
    get(:lookup_user, params: { id: "Einstein" })
    assert_redirected_to(controller: :observer, action: :index_rss_log)
    assert_flash_error
    # This caused router to crash in the wild.
    assert_recognizes({ controller: "observer", action: "lookup_user",
                        id: "I.+G.+Saponov" },
                      "/observer/lookup_user/I.+G.+Saponov")
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
      assert_redirected_to(action: :list_rss_logs)

      make_admin("rolf")
      get(:change_banner)
      assert_no_flash
      assert_response(:success)
      assert_textarea_value(:val, :app_banner_box.l)

      post(:change_banner, params: { val: "new banner" })
      assert_no_flash
      assert_redirected_to(action: :list_rss_logs)
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
    assert_match(/314159/, @response.body) # make sure fundis id in there!
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
    get(:intro)
    assert_equal(200, @response.status)
    get(:textile)
    assert_equal(200, @response.status)
  end

  def test_robot_permissions
    @request.user_agent = "Googlebot"
    get(:intro)
    assert_equal(200, @response.status)
    get(:textile)
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

  def test_site_stats
    get(:show_site_stats)

    assert_select("title").text.include?(:show_site_stats_title.l)
    assert_select("#title", { text: :show_site_stats_title.l },
                  "Displayed title should be #{:show_site_stats_title.l}")
    assert(/#{:site_stats_contributing_users.l}/ =~ @response.body,
           "Page is missing #{:site_stats_contributing_users.l}")
  end

  # ------------------------------------------------------------
  #  User
  #  observer_controller/user_controller
  # ------------------------------------------------------------

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
                    AND names.`rank` = #{Name.ranks[:Species]}").distinct

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
                    AND names.`rank` = #{Name.ranks[:Species]}").distinct

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
                    AND names.`rank` = #{Name.ranks[:Species]}").distinct

    get(:checklist, params: { project_id: project.id })
    assert_match(/Checklist for #{project.title}/, css_select("title").text,
                 "Wrong page")

    prove_checklist_content(expect)
  end

  # Prove that Site checklist goes to correct page with correct content
  def test_checklist_for_site
    expect = Name.joins(:observations).with_rank(:Species).distinct

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

  def test_suggestions
    obs = observations(:detailed_unknown_obs)
    name1 = names(:coprinus_comatus)
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
