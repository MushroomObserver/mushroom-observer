# encoding: utf-8
require "test_helper"

class ObserverControllerTest < FunctionalTestCase
  ##############################################################################
  # Helpers
  # TODO: can helpers move to separate file?  Will this filename work:
  # test/helpers/observer_controller_helper_test.rb

  def modified_generic_params(params, user)
    params[:observation] = sample_obs_fields.merge(params[:observation] || {})
    params[:vote] = { value: "3" }.merge(params[:vote] || {})
    params[:specimen] = default_specimen_fields.merge(params[:specimen] || {})
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
      thumb_image_id: "0"
    }
  end

  def default_specimen_fields
    { herbarium_name: "", herbarium_id: "" }
  end

  def location_exists_or_place_name_blank(params)
    Location.find_by_name(params[:observation][:place_name]) ||
      Location.is_unknown?(params[:observation][:place_name]) ||
      params[:observation][:place_name].blank?
  end
  ##############################################################################

  def test_show_observation_noteless_image
    obs = observations(:peltigera_rolf_observation)
    img = images(:rolf_profile_image)
    assert_nil(img.notes)
    assert(obs.images.member?(img))
    get_with_dump(:show_observation, id: obs.id)
  end

  def test_show_observation_noteful_image
    obs = observations(:detailed_unknown)
    get_with_dump(:show_observation, id: obs.id)
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
      if o_num == 0
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
      message = e.to_s + "\nFlash messages: (level #{$1})\n<" + flash + ">\n"
      flunk(message)
    end
    assert_equal(o_count + o_num, Observation.count, "Wrong Observation count")
    assert_equal(g_count + g_num, Naming.count, "Wrong Naming count")
    assert_equal(n_count + n_num, Name.count, "Wrong Name count")
    assert_equal(score + o_num + 2*g_num + 10*n_num, user.reload.contribution,
      "Wrong User score")
    if o_num == 1
      assert_not_equal(0,
        @controller.instance_variable_get("@observation").thumb_image_id,
        "Wrong image id")
    end
  end

################################################################################

  # ----------------------------
  #  General tests.
  # ----------------------------

  def test_page_loads
    get_with_dump(:index)
    assert_template(:list_rss_logs, partial: :_rss_log)
    assert_link_in_html(:app_intro.t, action: :intro)
    assert_link_in_html(:app_create_account.t, controller: :account,
                        action: :signup)

    get_with_dump(:ask_webmaster_question)
    assert_template(:ask_webmaster_question)
    assert_form_action(action: :ask_webmaster_question)

    get_with_dump(:color_themes)
    assert_template(:color_themes)
    for theme in MO.themes
      get_with_dump(theme)
      assert_template(theme)
    end

    get_with_dump(:how_to_help)
    assert_template(:how_to_help)

    get_with_dump(:how_to_use)
    assert_template(:how_to_use)

    get_with_dump(:intro)
    assert_template(:intro)

    get_with_dump(:list_observations)
    assert_template(:list_observations, partial: :_rss_log)

    # Test again, this time specifying page number via an observation id.
    get(:list_observations, id: 4)
    assert_template(:list_observations, partial: :_rss_log)

    get(:observations_for_project, id: projects(:bolete_project).id)
    assert_template(:list_observations, partial: :_rss_log)

    get_with_dump(:list_rss_logs)
    assert_template(:list_rss_logs, partial: :_rss_log)

    get_with_dump(:news)
    assert_template(:news)

    get_with_dump(:observations_by_name)
    assert_template(:list_observations, partial: :_rss_log)

    get_with_dump(:rss)
    assert_template(:rss)

    get_with_dump(:show_rss_log, id: 1)
    assert_template(:show_rss_log)

    get_with_dump(:users_by_contribution)
    assert_template(:users_by_contribution)

    get_with_dump(:show_user, id: 1)
    assert_template(:show_user)

    get_with_dump(:show_site_stats)
    assert_template(:show_site_stats)

    get_with_dump(:observations_by_user, id: 1)
    assert_template(:list_observations, partial: :_rss_log)

    # get_with_dump(:login)
    # assert_redirected_to(controller: :account, action: :login)

    get_with_dump(:textile)
    assert_template(:textile_sandbox)

    get_with_dump(:textile_sandbox)
    assert_template(:textile_sandbox)
  end

  def test_altering_types_shown_by_rss_log_index
    # Show none.
    post(:index_rss_log)
    assert_template(:list_rss_logs)

    # Show one.
    post(:index_rss_log, show_observations: "1")
    assert_template(:list_rss_logs)

    # Show all.
    params = {}
    for type in RssLog.all_types
      params["show_#{type}"] = "1"
    end
    post(:index_rss_log, params)
    assert_template(:list_rss_logs, partial: 1)
  end

  def test_prev_and_next_observation
    # Uses default observation query
    get(:next_observation, id: 4)
    assert_redirected_to(action: :show_observation, id: 3,
                         params: @controller.query_params(Query.last))

    get(:prev_observation, id: 4)
    assert_redirected_to(action: :show_observation, id: 5,
                        params: @controller.query_params(Query.last))
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
    query = Query.lookup_and_save(:Observation, :of_name, synonyms: :no,
                                  name: n2, by: :name)
    assert_equal(2, query.num_results)

    # Likewise, when requesting *synonym* observations, neither n1 nor n2
    # should be included.
    query = Query.lookup_and_save(:Observation, :of_name, synonyms: :exclusive,
                                  name: n2, by: :name)
    assert_equal(2, query.num_results)

    # But for our prev/next test, lets do the all-inclusive query.
    query = Query.lookup_and_save(:Observation, :of_name, synonyms: :all,
                                  name: n2, by: :name)
    assert_equal(4, query.num_results)
    qp = @controller.query_params(query)

    get(:next_observation, qp.merge(id: 1))
    assert_redirected_to(action: :show_observation, id: 1, params: qp)
    assert_flash(/can.*t find.*results.*index/i)
    get(:next_observation, qp.merge(id: o1.id))
    assert_redirected_to(action: :show_observation, id: o2.id, params: qp)
    get(:next_observation, qp.merge(id: o2.id))
    assert_redirected_to(action: :show_observation, id: o3.id, params: qp)
    get(:next_observation, qp.merge(id: o3.id))
    assert_redirected_to(action: :show_observation, id: o4.id, params: qp)
    get(:next_observation, qp.merge(id: o4.id))
    assert_redirected_to(action: :show_observation, id: o4.id, params: qp)
    assert_flash(/no more/i)

    get(:prev_observation, qp.merge(id: o4.id))
    assert_redirected_to(action: :show_observation, id: o3.id, params: qp)
    get(:prev_observation, qp.merge(id: o3.id))
    assert_redirected_to(action: :show_observation, id: o2.id, params: qp)
    get(:prev_observation, qp.merge(id: o2.id))
    assert_redirected_to(action: :show_observation, id: o1.id, params: qp)
    get(:prev_observation, qp.merge(id: o1.id))
    assert_redirected_to(action: :show_observation, id: o1.id, params: qp)
    assert_flash(/no more/i)
    get(:prev_observation, qp.merge(id: 1))
    assert_redirected_to(action: :show_observation, id: 1, params: qp)
    assert_flash(/can.*t find.*results.*index/i)
  end

  def test_advanced_search_form
    for model in [ Name, Image, Observation ]
      post("advanced_search_form",
        search: {
          name: "Don't know",
          user: "myself",
          type: model.name.underscore,
          content: "Long pink stem and small pink cap",
          location: "Eastern Oklahoma"
        },
        commit: "Search"
      )

      # assert_redirected_to(controller: model.show_controller,
      #                      action: :advanced_search)
      assert_response(:redirect)
      assert_match(%r{#{ model.show_controller }/advanced_search},
                   redirect_to_url)
    end
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Observation, :advanced_search,
      name: "Don't know",
      user: "myself",
      content: "Long pink stem and small pink cap",
      location: "Eastern Oklahoma"
    )
    get(:advanced_search, @controller.query_params(query))
    assert_template(:list_observations)
  end

  def test_advanced_search_2
    get(:advanced_search, name: "Agaricus", location: "California")
    assert_response(:success)
    results = @controller.instance_variable_get("@objects");
    assert_equal(4, results.length)
  end

  def test_advanced_search_3

    # Fail to include notes.
    get(:advanced_search,
      name: "Fungi",
      location: 'String in notes'
    )
    assert_response(:success)
    results = @controller.instance_variable_get('@objects');
    assert_equal(0, results.length)

    # Include notes, but notes don't have string yet!
    get(:advanced_search,
      name: "Fungi",
      location: '"String in notes"',
      search_location_notes: 1
    )
    assert_response(:success)
    results = @controller.instance_variable_get('@objects');
    assert_equal(0, results.length)

    # Add string to notes, make sure it is actually added.
    login("rolf")
    loc = locations(:burbank)
    loc.notes = 'blah blah blahString in notesblah blah blah'
    loc.save
    loc.reload
    assert(loc.notes.to_s.include?('String in notes'))

    # Forget to include notes again.
    get(:advanced_search,
      name: "Fungi",
      location: 'String in notes'
    )
    assert_response(:success)
    results = @controller.instance_variable_get('@objects');
    assert_equal(0, results.length)

    # Now it should finally find the three unknowns at Burbank because Burbank
    # has the magic string in its notes, and we're looking for it.
    get(:advanced_search,
      name: "Fungi",
      location: '"String in notes"',
      search_location_notes: 1
    )
    assert_response(:success)
    results = @controller.instance_variable_get('@objects');
    assert_equal(3, results.length)
  end

  def test_pattern_search
    params = {search: {pattern: "12", type: :observation}}
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :observer, action: :observation_search,
                    pattern: "12")

    params = {search: {pattern: "34", type: :image}}
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :image, action: :image_search,
                    pattern: "34")

    params = {search: {pattern: "56", type: :name}}
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :name, action: :name_search,
                    pattern: "56")

    params = {search: {pattern: "78", type: :location}}
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :location, action: :location_search,
                    pattern: "78")

    params = {search: {pattern: "90", type: :comment}}
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :comment, action: :comment_search,
                    pattern: "90")

    params = {search: {pattern: "12", type: :species_list}}
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :species_list, action: :species_list_search,
                         pattern: "12")

    params = {search: {pattern: "34", type: :user}}
    get_with_dump(:pattern_search, params)
    assert_redirected_to(controller: :observer, action: :user_search,
                         pattern: "34")
  end

  def test_observation_search
    get_with_dump(:observation_search, pattern: "120")
    assert_template(:list_observations)
    assert_equal(:query_title_pattern_search.t(types: "Observations",
                                               pattern: "120"),
                 @controller.instance_variable_get('@title'))

    get_with_dump(:observation_search, pattern: "120", page: 2)
    assert_template(:list_observations)
    assert_equal(:query_title_pattern_search.t(types: "Observations",
                                               pattern: "120"),
                 @controller.instance_variable_get('@title'))
  end

  def test_observation_search_with_spelling_correction
    # Missing the stupid genus Coprinus: breaks the alternate name suggestions.
    login("rolf")
    Name.find_or_create_name_and_parents('Coprinus comatus').each(&:save!)
    names = Name.suggest_alternate_spellings('Coprinus comatis')
    assert_not_equal([], names.map(&:search_name))

    get(:observation_search, pattern: 'coprinis comatis')
    assert_template(:list_observations)
    assert_equal('coprinis comatis', assigns(:suggest_alternate_spellings))
    assert_select('div.Warnings', 1)
    assert_select('a[href*=observation_search?pattern=Coprinus+comatus]',
                  text: names(:coprinus_comatus).search_name)

    get(:observation_search, pattern: 'Coprinus comatus')
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

  def test_send_webmaster_question
    ask_webmaster_test("rolf@mushroomobserver.org",
      response: {controller: :observer, action: :list_rss_logs})
  end

  def test_send_webmaster_question_need_address
    ask_webmaster_test("", flash: :runtime_ask_webmaster_need_address.t)
  end

  def test_send_webmaster_question_spammer
    ask_webmaster_test("spammer", flash: :runtime_ask_webmaster_need_address.t)
  end

  def test_send_webmaster_question_need_content
    ask_webmaster_test("bogus@email.com", content: "",
      flash: :runtime_ask_webmaster_need_content.t)
  end

  def test_send_webmaster_question_antispam
    disable_unsafe_html_filter
    ask_webmaster_test("bogus@email.com",
      content: "Buy <a href='http://junk'>Me!</a>",
      flash: :runtime_ask_webmaster_antispam.t)
  end

  def ask_webmaster_test(email, args)
    response = args[:response] || :success
    flash = args[:flash]
    post(:ask_webmaster_question, {
      user: { email: email },
      question: { content: (args[:content] || "Some content")}})
    assert_response(response)
    assert_flash(flash) if flash
  end

  def test_show_observation_num_views
    obs = observations(:coprinus_comatus_obs)
    updated_at = obs.updated_at
    num_views = obs.num_views
    last_view = obs.last_view
    # obs.update_view_stats
    get_with_dump(:show_observation, id: obs.id)
    obs.reload
    assert_equal(num_views+1, obs.num_views)
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
    assert_equal(0, Query.count)

    # Test it on obs with no namings first.
    obs_id = observations(:unknown_with_no_naming).id
    get_with_dump(:show_observation, id: obs_id)
    assert_show_observation
    assert_form_action(action: :show_observation, id: obs_id)

    # Test it on obs with two namings (Rolf's and Mary's), but no one logged in.
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show_observation, id: obs_id)
    assert_show_observation
    assert_form_action(action: :show_observation, id: obs_id)

    # Test it on obs with two namings, with owner logged in.
    login("rolf")
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show_observation, id: obs_id)
    assert_show_observation
    assert_form_action(action: :show_observation, id: obs_id)

    # Test it on obs with two namings, with non-owner logged in.
    login("mary")
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show_observation, id: obs_id)
    assert_show_observation
    assert_form_action(action: :show_observation, id: obs_id)

    # Test a naming owned by the observer but the observer has 'No Opinion'.
    # Ensure that rolf owns @obs_with_no_opinion.
    user = login("rolf")
    obs = observations(:strobilurus_diminutivus_obs)
    assert_equal(obs.user, user)
    get(:show_observation, id: obs.id)
    assert_show_observation

    # Make sure no queries created for show_image links.  (Well, okay, four
    # queries are created for Darvin's new "show species" and "show similar
    # observations" links...)
    assert_equal(4, Query.count)
  end

  def test_show_observation_edit_links
    obs = observations(:detailed_unknown)
    proj = projects(:bolete_project)
    assert_equal(mary.id, obs.user_id)                        # owned by mary
    assert(obs.projects.include?(proj))                       # owned by bolete project
    assert_equal([dick.id], proj.user_group.users.map(&:id))  # dick is only member of bolete project

    login("rolf")
    get(:show_observation, id: obs.id)
    assert_select('a[href*=edit_observation]', count: 0)
    assert_select('a[href*=destroy_observation]', count: 0)
    assert_select('a[href*=add_image]', count: 0)
    assert_select('a[href*=remove_image]', count: 0)
    assert_select('a[href*=reuse_image]', count: 0)
    get(:edit_observation, id: obs.id)
    assert_response(:redirect)
    get(:destroy_observation, id: obs.id)
    assert_flash_error

    login("mary")
    get(:show_observation, id: obs.id)
    assert_select('a[href*=edit_observation]', minimum: 1)
    assert_select('a[href*=destroy_observation]', minimum: 1)
    assert_select('a[href*=add_image]', minimum: 1)
    assert_select('a[href*=remove_image]', minimum: 1)
    assert_select('a[href*=reuse_image]', minimum: 1)
    get(:edit_observation, id: obs.id)
    assert_response(:success)

    login("dick")
    get(:show_observation, id: obs.id)
    assert_select('a[href*=edit_observation]', minimum: 1)
    assert_select('a[href*=destroy_observation]', minimum: 1)
    assert_select('a[href*=add_image]', minimum: 1)
    assert_select('a[href*=remove_image]', minimum: 1)
    assert_select('a[href*=reuse_image]', minimum: 1)
    get(:edit_observation, id: obs.id)
    assert_response(:success)
    get(:destroy_observation, id: obs.id)
    assert_flash_success
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

    id = images(:in_situ).id
    requires_login(:commercial_inquiry, id: id)
    assert_form_action(action: :commercial_inquiry, id: id)
  end

  def test_destroy_observation
    assert(obs = observations(:minimal_unknown))
    id = obs.id
    params = { id: id.to_s }
    assert_equal("mary", obs.user.login)
    requires_user(:destroy_observation, [action: :show_observation],
                  params, "mary")
    assert_redirected_to(action: :list_observations)
    assert_raises(ActiveRecord::RecordNotFound) do
      obs = Observation.find(id)
    end
  end

  def test_some_admin_pages
    for (page, response, params) in [
      [ :users_by_name,  "list_users",  {} ],
      [ :email_features, "email_features", {} ]
    ]
      logout
      get(page, params)
      assert_redirected_to(controller: :account, action: :login)

      login("rolf")
      get(page, params)
      assert_redirected_to(action: :list_rss_logs)
      assert_flash(/denied|only.*admin/i)

      make_admin("rolf")
      get_with_dump(page, params)
      assert_template(response) # 1
    end
  end

  def test_email_features
    page = :email_features
    params = {feature_email: {content: "test"}}

    logout
    post(page, params)
    assert_redirected_to(controller: :account, action: :login)

    login("rolf")
    post(page, params)
    assert_redirected_to(controller: :observer, action: :list_rss_logs)
    assert_flash(/denied|only.*admin/i)

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
    obs = observations(:minimal_unknown)
    params = {
      id: obs.id,
      question: {
        content: "Testing question"
      }
    }
    post_requires_login(:ask_observation_question, params)
    assert_redirected_to(action: :show_observation)
    assert_flash(:runtime_ask_observation_question_success.t)
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
    assert_flash(:runtime_ask_user_question_success.t)
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
    QueuedEmail::NameTracking.create_email(note,
      namings(:coprinus_comatus_other_naming))

    # Now we can be sure show_notifications is supposed to actually show a
    # non-empty list, and thus that this test is meaningful.
    requires_login(:show_notifications,
      id: observations(:coprinus_comatus_obs).id)
    assert_template(:show_notifications)
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
    assert_redirected_to(controller: :name, action: :show_name_description,
                         id: name_descriptions(:coprinus_comatus_desc).id)
    assert_flash(:request_success.t)

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
    assert_flash(:request_success.t)
  end

  def test_review_authors_locations
    desc = location_descriptions(:albion_desc)
    params = { id: desc.id, type: "LocationDescription" }
    desc.authors.clear
    assert_user_list_equal([], desc.reload.authors)

    # Make sure it lets Rolf and only Rolf see this page.
    assert(!mary.in_group?("reviewers"))
    assert(rolf.in_group?("reviewers"))
    requires_user(:review_authors, [controller: :location,
                    action: :show_location, id: desc.location_id], params)
    assert_template(:review_authors)

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(rolf)
    rolf.reload
    assert(!rolf.in_group?("reviewers"))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, params)
    assert_redirected_to(controller: :location, action: :show_location,
                         id: desc.id)

    # Make Rolf an author.
    desc.add_author(rolf)
    desc.save
    desc.reload
    assert_user_list_equal([rolf], desc.authors)

    # Rolf should be able to do it now.
    get(:review_authors, params)
    assert_template(:review_authors)

    # Rolf giveth with one hand...
    post(:review_authors, params.merge(add: mary.id))
    assert_template(:review_authors)
    desc.reload
    assert_user_list_equal([mary, rolf], desc.authors)

    # ...and taketh with the other.
    post(:review_authors, params.merge(remove: mary.id))
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
    assert(!rolf.reload.in_group?("reviewers"))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, params)
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)

    # Make Rolf an author.
    desc.add_author(rolf)
    assert_user_list_equal([rolf], desc.reload.authors)

    # Rolf should be able to do it again now.
    get(:review_authors, params)
    assert_template(:review_authors)

    # Rolf giveth with one hand...
    post(:review_authors, params.merge(add: mary.id))
    assert_template(:review_authors)
    assert_user_list_equal([mary, rolf], desc.reload.authors)

    # ...and taketh with the other.
    post(:review_authors, params.merge(remove: mary.id))
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
    get("set_export_status", params)
    assert_redirected_to(controller: :account, action: :login)

    # Require reviewer.
    login("dick")
    get("set_export_status", params)
    assert_flash_error
    logout

    # Require correct params.
    login("rolf")
    get("set_export_status", params.merge(id: 9999))
    assert_flash_error
    get("set_export_status", params.merge(type: "bogus"))
    assert_flash_error
    get("set_export_status", params.merge(value: "true"))
    assert_flash_error

    # Now check *correct* usage.
    assert_equal(true, name.reload.ok_for_export)
    get("set_export_status", params.merge(value: "0"))
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)
    assert_equal(false, name.reload.ok_for_export)
    get("set_export_status", params.merge(value: "1"))
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)
    assert_equal(true, name.reload.ok_for_export)
  end

  def test_original_filename_visibility
    login("mary")

    rolf.keep_filenames = :toss
    rolf.save
    get(:show_observation, id: 4)
    assert_false(@response.body.include?('áč€εиts'))

    rolf.keep_filenames = :keep_but_hide
    rolf.save
    get(:show_observation, id: 4)
    assert_false(@response.body.include?('áč€εиts'))

    rolf.keep_filenames = :keep_and_show
    rolf.save
    get(:show_observation, id: 4)
    assert_true(@response.body.include?('áč€εиts'))

    login("rolf") # owner

    rolf.keep_filenames = :toss
    rolf.save
    get(:show_observation, id: 4)
    assert_true(@response.body.include?('áč€εиts'))

    rolf.keep_filenames = :keep_but_hide
    rolf.save
    get(:show_observation, id: 4)
    assert_true(@response.body.include?('áč€εиts'))

    rolf.keep_filenames = :keep_and_show
    rolf.save
    get(:show_observation, id: 4)
    assert_true(@response.body.include?('áč€εиts'))
  end

  # ------------------------------
  #  Test creating observations.
  # ------------------------------

  # Test "get" side of create_observation.
  def test_create_observation
    requires_login(:create_observation)
    assert_form_action(action: :create_observation, approved_name: "")
    assert_input_value(:specimen_herbarium_name,
      users(:rolf).preferred_herbarium_name)
    assert_input_value(:specimen_herbarium_id, "")
  end

  def test_construct_observation_approved_place_name
    where = "Albion, California, USA"
    generic_construct_observation({
      observation: { place_name: where},
      name: { name: "Coprinus comatus"},
      approved_place_name: ""
    }, 1, 1, 0)
    obs = assigns(:observation)
    assert_equal(where, obs.place_name)
  end

  def test_create_observation_with_herbarium
    generic_construct_observation({
      observation: { specimen: "1" },
      specimen: { herbarium_name: herbaria(:nybg).name, herbarium_id: "1234" },
      name: { name: "Coprinus comatus" }
    }, 1, 1, 0)
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.specimens.count == 1)
  end

  def test_create_observation_with_herbarium_duplicate_label
    generic_construct_observation({
      observation: { specimen: "1" },
      specimen: { herbarium_name: herbaria(:nybg).name,
                  herbarium_id: "NYBG 1234" },
      name: { name: "Cortinarius sp." }
    }, 0,0,0)
    assert_input_value(:specimen_herbarium_name,
      "The New York Botanical Garden")
    assert_input_value(:specimen_herbarium_id, "NYBG 1234")
  end

  def test_create_observation_with_herbarium_no_id
    name = "Coprinus comatus"
    generic_construct_observation({
      observation: { specimen: "1" },
      specimen: { herbarium_name: herbaria(:nybg).name, herbarium_id: "" },
      name: { name: name }
    }, 1, 1, 0)
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.specimens.count == 1)
    specimen = obs.specimens[0]
    assert(/#{obs.id}/ =~ specimen.herbarium_label)
    assert(/#{name}/ =~ specimen.herbarium_label)
  end

  def test_create_observation_with_herbarium_but_no_specimen
    generic_construct_observation({
      specimen: { herbarium_name: herbaria(:nybg).name, herbarium_id: "1234" },
      name: { name: "Coprinus comatus" }
    }, 1, 1, 0)
    obs = assigns(:observation)
    assert(!obs.specimen)
    assert(obs.specimens.count == 0)
  end

  def test_create_observation_with_new_herbarium
    generic_construct_observation({
      observation: { specimen: "1" },
      specimen: { herbarium_name: "A Brand New Herbarium", herbarium_id: "" },
      name: { name: "Coprinus comatus" }
    }, 1, 1, 0)
    obs = assigns(:observation)
    assert(obs.specimen)
    assert(obs.specimens.count == 1)
    specimen = obs.specimens[0]
    herbarium = specimen.herbarium
    assert(herbarium.is_curator?(rolf))
  end

  def test_create_simple_observation_with_approved_unique_name
    where = "Simple, Massachusetts, USA"
    generic_construct_observation({
      observation: { place_name: where, thumb_image_id: "0" },
      name: { name: "Coprinus comatus" }
    }, 1,1,0)
    obs = assigns(:observation)
    nam = assigns(:naming)
    assert_equal(where, obs.where)
    assert_equal(names(:coprinus_comatus).id, nam.name_id)
    assert_equal("2.03659", "%.5f" % obs.vote_cache)
    assert_not_nil(obs.rss_log)
    # This was getting set to zero instead of nil if no images were uploaded
    # when obs was created.
    assert_equal(nil, obs.thumb_image_id)
  end

  def test_create_simple_observation_of_unknown_taxon
    where = "Unknown, Massachusetts, USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 1,0,0)
    obs = assigns(:observation)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_new_name
    generic_construct_observation({
      name: { name: "New name" }
    }, 0,0,0)
  end

  def test_create_observation_with_approved_new_name
    # Test an observation creation with an approved new name
    generic_construct_observation({
      name: { name: "Argus arg-arg" },
      approved_name: "Argus arg-arg"
    }, 1,1,2)
  end

  def test_create_observation_with_approved_name_and_extra_space
    generic_construct_observation({
      name: { name: "Another new-name" + "  " },
      approved_name: "Another new-name" + "  "
    }, 1,1,2)
  end

  def test_create_observation_with_approved_section
    # (This is now supported nominally)
    # (Use Macrocybe because it already exists and has an author.
    # That way we know it is actually creating a name for this section.)
    generic_construct_observation({
      name: { name: "Macrocybe section Fakesection" },
      approved_name: "Macrocybe section Fakesection"
    }, 1,1,1)
  end

  def test_create_observation_with_approved_junk_name
    generic_construct_observation({
      name: { name: "This is a bunch of junk" },
      approved_name: "This is a bunch of junk"
    }, 0,0,0)
  end

  def test_create_observation_with_multiple_name_matches
    generic_construct_observation({
      name: { name: "Amanita baccata" }
    }, 0,0,0)
  end

  def test_create_observation_choosing_one_of_multiple_name_matches
    generic_construct_observation({
      name: { name: "Amanita baccata" },
      chosen_name: { name_id: names(:amanita_baccata_arora).id }
    }, 1,1,0)
  end

  def test_create_observation_choosing_deprecated_one_of_multiple_name_matches
    generic_construct_observation({
      name: { name: names(:pluteus_petasatus_deprecated).text_name }
    }, 1,1,0)
    nam = assigns(:naming)
    assert_equal(names(:pluteus_petasatus_approved).id, nam.name_id)
  end

  def test_create_observation_with_deprecated_name
    generic_construct_observation({
      name: { name: "Lactarius subalpinus" }
    }, 0,0,0)
  end

  def test_create_observation_with_chosen_approved_synonym_of_deprecated_name
    generic_construct_observation({
      name: { name: "Lactarius subalpinus" },
      approved_name: "Lactarius subalpinus",
      chosen_name: { name_id: names(:lactarius_alpinus).id }
    }, 1,1,0)
    nam = assigns(:naming)
    assert_equal(nam.name, names(:lactarius_alpinus))
  end

  def test_create_observation_with_approved_deprecated_name
    generic_construct_observation({
      name: { name: "Lactarius subalpinus" },
      approved_name: "Lactarius subalpinus",
      chosen_name: { }
    }, 1,1,0)
    nam = assigns(:naming)
    assert_equal(nam.name, names(:lactarius_subalpinus))
  end

  def test_create_observation_with_approved_new_species
    # Test an observation creation with an approved new name
    Name.find_by_text_name("Agaricus").destroy
    generic_construct_observation({
      name: { name: "Agaricus novus" },
      approved_name: "Agaricus novus"
    }, 1,1,2)
    name = Name.find_by_text_name("Agaricus novus")
    assert(name)
    assert_equal("Agaricus novus", name.text_name)
  end

  def test_create_observation_that_generates_email
    QueuedEmail.queue_emails(true)
    count_before = QueuedEmail.count
    name = names(:agaricus_campestris)
    notifications = Notification.where(flavor: :name, obj_id: name.id)
    assert_equal(2, notifications.length)

    where = "Simple, Massachusetts, USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: name.text_name }
    }, 1,1,0)
    obs = assigns(:observation)
    nam = assigns(:naming)

    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_equal(name.id, nam.name_id) # Make sure it's the right name
    assert_not_nil(obs.rss_log)
    assert_equal(count_before+2, QueuedEmail.count)
  end

  def test_create_observation_with_decimal_geolocation_and_unknown_name
    lat = 34.1622
    long = -118.3521
    generic_construct_observation({
      observation: { place_name: "", lat: lat, long: long },
      name: { name: "Unknown" },
    }, 1,0,0)
    obs = assigns(:observation)

    assert_equal(lat.to_s, obs.lat.to_s)
    assert_equal(long.to_s, obs.long.to_s)
    assert_objs_equal(Location.unknown, obs.location)
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_dms_geolocation_and_unknown_name
    lat2 = '34°9’43.92”N'
    long2 = '118°21′7.56″W'
    generic_construct_observation({
      observation: { place_name: "", lat: lat2, long: long2 },
      name: { name: "Unknown" },
    }, 1,0,0)
    obs = assigns(:observation)

    assert_equal("34.1622", obs.lat.to_s)
    assert_equal("-118.3521", obs.long.to_s)
    assert_objs_equal(Location.unknown, obs.location)
    assert_not_nil(obs.rss_log)
  end

  def test_create_observation_with_empty_geolocation_and_location
    # Make sure it doesn't accept no location AND no lat/long.
    generic_construct_observation({
      observation: { place_name: "", lat: "", long: "" },
      name: { name: "Unknown" },
    }, 0,0,0)
  end

  def test_create_observations_with_unknown_location_and_empty_geolocation
    # But create observation if explicitly tell it "unknown" location.
    generic_construct_observation({
      observation: { place_name: "Earth", lat: "", long: "" },
      name: { name: "Unknown" },
    }, 1,0,0)
  end

  def test_create_observation_with_various_altitude_formats
    for input, output in [
        [ "500",     500 ],
        [ "500m",    500 ],
        [ "500 ft.", 152 ],
        [ ' 500\' ', 152 ]
      ]
      where = "Unknown, Massachusetts, USA"

      generic_construct_observation({
        observation: { place_name: where, alt: input },
        name: { name: "Unknown" },
      }, 1,0,0)
      obs = assigns(:observation)

      assert_equal(output, obs.alt)
      assert_equal(where, obs.where) # Make sure it's the right observation
      assert_not_nil(obs.rss_log)
    end

  end

  def test_create_observation_creating_class
    generic_construct_observation({
      observation: { place_name: "Earth", lat: "", long: "" },
      name: { name: "Lecanoromycetes L." },
      approved_name: "Lecanoromycetes L.",
    }, 1,1,1)
    name = Name.last
    assert_equal("Lecanoromycetes", name.text_name)
    assert_equal('L.', name.author)
    assert_equal(:Class, name.rank)
  end

  def test_create_observation_creating_family
    params = {
      observation: { place_name: "Earth", lat: "", long: "" },
      name: { name: "Acarosporaceae" },
      approved_name: "Acarosporaceae",
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
    assert_equal(score + o_num + 2*g_num + 10*n_num, user.reload.contribution,
      "Wrong User score")
    assert_not_equal(0,
      @controller.instance_variable_get("@observation").thumb_image_id,
      "Wrong image id")

    assert_equal("Acarosporaceae", name.text_name, )
    assert_equal(:Family, name.rank)
  end

  def test_create_observation_creating_group
    generic_construct_observation({
      observation: { place_name: "Earth", lat: "", long: "" },
      name: { name: "Morchella elata group" },
      approved_name: "Morchella elata group",
    }, 1,1,2)

    name = Name.last
    assert_equal("Morchella elata group", name.text_name)
    assert_equal("", name.author)
    assert_equal(:Group, name.rank)
  end

  def test_prevent_creation_of_species_under_deprecated_genus
    login("katrina")
    cladonia = Name.find_or_create_name_and_parents("Cladonia").last
    cladonia.save!
    cladonia_picta = Name.find_or_create_name_and_parents('Cladonia picta').last
    cladonia_picta.save!
    cladina = Name.find_or_create_name_and_parents("Cladina").last
    cladina.change_deprecated(true)
    cladina.save!
    cladina.merge_synonyms(cladonia)

    generic_construct_observation({
      observation: { place_name: "Earth" },
      name: { name: "Cladina pictum" },
    }, 0,0,0, roy)
    assert_names_equal(cladina, assigns(:parent_deprecated))
    assert_obj_list_equal([cladonia_picta], assigns(:valid_names))

    generic_construct_observation({
      observation: { place_name: "Earth" },
      name: { name: "Cladina pictum" },
      approved_name: "Cladina pictum",
    }, 1,1,1, roy)

    name = Name.last
    assert_equal('Cladina pictum', name.text_name)
    assert_true(name.deprecated)
  end

  def test_construct_observation_dubious_place_names
    # Test a reversed name with a scientific user
    where = "USA, Massachusetts, Reversed"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 1,0,0, roy)

    # Test missing space.
    where = "Reversible, Massachusetts,USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0)
    # (This is accepted now for some reason.)
    where = "USA,Massachusetts, Reversible"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 1,0,0, roy)

    # Test a bogus country name
    where = "Bogus, Massachusetts, UAS"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0)
    where = "UAS, Massachusetts, Bogus"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0, roy)

    # Test a bad state name
    where = "Bad State Name, USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0)
    where = "USA, Bad State Name"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0, roy)

    # Test mix of city and county
    where = "Burbank, Los Angeles Co., California, USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0)
    where = "USA, California, Los Angeles Co., Burbank"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0, roy)

    # Test mix of city and county
    where = "Falmouth, Barnstable Co., Massachusetts, USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0)
    where = "USA, Massachusetts, Barnstable Co., Falmouth"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0, roy)

    # Test some bad terms
    where = "Some County, Ohio, USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0)
    where = "Old Rd, Ohio, USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 0,0,0)
    where = "Old Rd., Ohio, USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 1,0,0)

    # Test some acceptable additions
    where = "near Burbank, Southern California, USA"
    generic_construct_observation({
      observation: { place_name: where },
      name: { name: "Unknown" }
    }, 1,0,0)
  end

  def test_name_resolution
    login("rolf")

    params = {
      observation: {
        when: Time.now,
        place_name: "Somewhere, Massachusetts, USA",
        specimen: "0",
        thumb_image_id: "0",
      },
      name: {},
      vote: { value: "3" },
    }
    expected_page = :create_location

    # Can we create observation with existing genus?
    agaricus = names(:agaricus)
    params[:name][:name] = "Agaricus"
    params[:approved_name] = nil
    post(:create_observation, params)
    # assert_template(action: expected_page)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp.'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(agaricus.id, assigns(:observation).name_id)

    # Can we create observation with genus and add author?
    params[:name][:name] = 'Agaricus Author'
    params[:approved_name] = 'Agaricus Author'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal('Agaricus Author', agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = "Agaricus"
    agaricus.save

    params[:name][:name] = 'Agaricus sp Author'
    params[:approved_name] = 'Agaricus sp Author'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal('Agaricus Author', agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = "Agaricus"
    agaricus.save

    params[:name][:name] = 'Agaricus sp. Author'
    params[:approved_name] = 'Agaricus sp. Author'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal('Agaricus Author', agaricus.reload.search_name)

    # Can we create observation with genus specifying author?
    params[:name][:name] = 'Agaricus Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp. Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(agaricus.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus?
    psalliota = names(:psalliota)
    params[:name][:name] = "Psalliota"
    params[:approved_name] = "Psalliota"
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = 'Psalliota sp'
    params[:approved_name] = 'Psalliota sp'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = 'Psalliota sp.'
    params[:approved_name] = 'Psalliota sp.'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(psalliota.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus, adding author?
    params[:name][:name] = 'Psalliota Author'
    params[:approved_name] = 'Psalliota Author'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal('Psalliota Author', psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = "Psalliota"
    psalliota.save

    params[:name][:name] = 'Psalliota sp Author'
    params[:approved_name] = 'Psalliota sp Author'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal('Psalliota Author', psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = "Psalliota"
    psalliota.save

    params[:name][:name] = 'Psalliota sp. Author'
    params[:approved_name] = 'Psalliota sp. Author'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal('Psalliota Author', psalliota.reload.search_name)

    # Can we create new quoted genus?
    params[:name][:name] = '"One"'
    params[:approved_name] = '"One"'
    post(:create_observation, params)
    # assert_template(controller: :observer, action: expected_page)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One"', assigns(:observation).name.search_name)

    params[:name][:name] = '"Two" sp'
    params[:approved_name] = '"Two" sp'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"Two"', assigns(:observation).name.text_name)
    assert_equal('"Two"', assigns(:observation).name.search_name)

    params[:name][:name] = '"Three" sp.'
    params[:approved_name] = '"Three" sp.'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"Three"', assigns(:observation).name.text_name)
    assert_equal('"Three"', assigns(:observation).name.search_name)

    params[:name][:name] = '"One"'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp.'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"One"', assigns(:observation).name.text_name)

    # Can we create species under the quoted genus?
    params[:name][:name] = '"One" foo'
    params[:approved_name] = '"One" foo'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"One" foo', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" "bar"'
    params[:approved_name] = '"One" "bar"'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"One" "bar"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" Author'
    params[:approved_name] = '"One" Author'
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp. Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(%r{#{ expected_page }})
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" Author', assigns(:observation).name.search_name)
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
    requires_user(:edit_observation, [controller: :observer,
                  action: :show_observation], params)
    assert_form_action(action: :edit_observation, id: obs.id.to_s)
  end

  def test_edit_observation
    obs = observations(:detailed_unknown)
    updated_at = obs.rss_log.updated_at
    new_where = "Somewhere In, Japan"
    new_notes = "blather blather blather"
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
        thumb_image_id: "0",
      },
      good_images: "1 2",
      good_image: {
        "1" => {
          notes: "new notes",
          original_name: "new name",
          copyright_holder: "someone else",
          "when(1i)" => "2012",
          "when(2i)" => "4",
          "when(3i)" => "6",
          license_id: "3",
        }
      },
      log_change: { checked: "1" }
    }
    post_requires_user(:edit_observation, [controller: :observer,
                  action: :show_observation], params, "mary")
    # assert_redirected_to(controller: :location, action: :create_location)
    assert_redirected_to(%r{#{ url_for(controller: :location,
                                       action: :create_location) }})
    assert_equal(10, rolf.reload.contribution)
    obs = assigns(:observation)
    assert_equal(new_where, obs.where)
    assert_equal("2001-02-03", obs.when.to_s)
    assert_equal(new_notes, obs.notes)
    assert_equal(new_specimen, obs.specimen)
    assert_not_equal(updated_at, obs.rss_log.updated_at)
    assert_not_equal(0, obs.thumb_image_id)
    img = images(:in_situ).reload
    assert_equal("new notes", img.notes)
    assert_equal("new name", img.original_name)
    assert_equal('someone else', img.copyright_holder)
    assert_equal('2012-04-06', img.when.to_s)
    assert_equal(licenses(:ccwiki30), img.license)
  end

  def test_edit_observation_no_logging
    obs = observations(:detailed_unknown)
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
    post_requires_user(:edit_observation, [controller: :observer,
                       action: :show_observation], params, "mary")
    # assert_redirected_to(controller: :location, action: :create_location)
    assert_redirected_to(%r{/location/create_location})
    assert_equal(10, rolf.reload.contribution)
    obs = assigns(:observation)
    assert_equal(where, obs.where)
    assert_equal(updated_at, obs.rss_log.updated_at)
  end

  def test_edit_observation_bad_place_name
    obs = observations(:detailed_unknown)
    updated_at = obs.rss_log.updated_at
    new_where = "test_update_observation"
    new_notes = "blather blather blather"
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
    post_requires_user(:edit_observation, [controller: :observer,
                       action: :show_observation], params, "mary")
    assert_response(:success) # Which really means failure
  end

  def test_edit_observation_with_another_users_image
    img1 = images(:in_situ)
    img2 = images(:turned_over)
    img3 = images(:commercial_inquiry_image)

    obs = observations(:detailed_unknown)
    obs.images << img3
    obs.save
    obs.reload

    assert_equal(img1.user_id, obs.user_id)
    assert_equal(img2.user_id, obs.user_id)
    assert_not_equal(img3.user_id, obs.user_id)

    img_ids = obs.images.map(&:id)
    assert_equal([1, 2, 3], img_ids)

    old_img1_notes = img1.notes
    old_img2_notes = img2.notes
    old_img3_notes = img3.notes

    params = {
      id: obs.id.to_s,
      observation: {
        place_name: obs.place_name,
        when: obs.when,
        notes: obs.notes,
        specimen: obs.specimen,
        thumb_image_id: "0",
      },
      good_images: img_ids.map(&:to_s).join(' '),
      good_image: {
        img2.id.to_s => { notes: 'new notes for two', },
        img3.id.to_s => { notes: 'new notes for three', },
      },
    }
    login("mary")
    post(:edit_observation, params)
    assert_redirected_to(action: :show_observation)
    assert_flash_success
    assert_equal(old_img1_notes, img1.reload.notes)
    assert_equal('new notes for two', img2.reload.notes)
    assert_equal(old_img3_notes, img3.reload.notes)
  end

  def test_edit_observation_with_non_image
    obs = observations(:minimal_unknown)
    file = Rack::Test::UploadedFile.new(
      "#{Rails.root}/test/fixtures/projects.yml", "text/plain"
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
          when: Time.now
        }
      }
    }
    login("mary")
    post(:edit_observation, params)

    assert_response(:success,
      "Expected 200 (OK), Got #{@response.status} (#{@response.message})")
    # 200 :success means means failure!
    assert_flash_error
  end


  # ----------------------------
  #  Test voting.
  # ----------------------------

  # Now have Dick vote on Mary's name.
  # Votes: rolf=2/-3, mary=1/3, dick=-1/3
  # Rolf prefers naming 3 (vote 2 -vs- -3).
  # Mary prefers naming 9 (vote 1 -vs- 3).
  # Dick now prefers naming 9 (vote 3).
  # Summing, 3 gets 2+1/3=1, 9 gets -3+3+3/4=.75, so 3 gets it.
  def test_cast_vote_dick
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login("dick")
    post(:cast_vote, value: "3", id: nam2.id)
    assert_equal(11, dick.reload.contribution)

    # Check votes.
    assert_equal(3, nam1.reload.vote_sum)
    assert_equal(2, nam1.votes.length)
    assert_equal(3, nam2.reload.vote_sum)
    assert_equal(3, nam2.votes.length)

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # If Dick votes on the other as well, then his first vote should
    # get demoted and his preference should change.
    # Summing, 3 gets 2+1+3/4=1.5, 9 gets -3+3+2/4=.5, so 3 keeps it.
    obs.change_vote(nam1, 3, dick)
    assert_equal(12, dick.reload.contribution)
    assert_equal(3, nam1.reload.users_vote(dick).value)
    assert_equal(6, nam1.vote_sum)
    assert_equal(3, nam1.votes.length)
    assert_equal(2, nam2.reload.users_vote(dick).value)
    assert_equal(2, nam2.vote_sum)
    assert_equal(3, nam2.votes.length)
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)
  end

  # Now have Rolf change his vote on his own naming. (no change in prefs)
  # Votes: rolf=3->2/-3, mary=1/3, dick=x/x
  def test_cast_vote_rolf_change
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login("rolf")
    post(:cast_vote, value: "2", id: nam1.id)
    assert_equal(10, rolf.reload.contribution)

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check vote.
    assert_equal(3, nam1.reload.vote_sum)
    assert_equal(2, nam1.votes.length)
  end

  # Now have Rolf increase his vote for Mary's. (changes consensus)
  # Votes: rolf=2/-3->3, mary=1/3, dick=x/x
  def test_cast_vote_rolf_second_greater
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login("rolf")
    post(:cast_vote, value: "3", id: nam2.id)
    assert_equal(10, rolf.reload.contribution)

    # Make sure observation was updated right.
    assert_equal(names(:agaricus_campestris).id, obs.reload.name_id)

    # Check vote.
    assert_equal(6, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  # Now have Rolf increase his vote for Mary's insufficiently. (no change)
  # Votes: rolf=2/-3->-1, mary=1/3, dick=x/x
  # Summing, 3 gets 2+1=3, 9 gets -1+3=2, so 3 keeps it.
  def test_cast_vote_rolf_second_lesser
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login("rolf")
    post(:cast_vote,
      value: "-1",
      id: nam2.id
    )
    assert_equal(10, rolf.reload.contribution)

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check vote.
    assert_equal(3, nam1.reload.vote_sum)
    assert_equal(2, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  # Now, have Mary delete her vote against Rolf's naming.  This NO LONGER has the effect
  # of excluding Rolf's naming from the consensus calculation due to too few votes.
  # (Have Dick vote first... I forget what this was supposed to test for, but it's clearly
  # superfluous now).
  # Votes: rolf=2/-3, mary=1->x/3, dick=x/x->3
  # Summing after Dick votes,   3 gets 2+1/3=1, 9 gets -3+3+3/4=.75, 3 keeps it.
  # Summing after Mary deletes, 3 gets 2/2=1,   9 gets -3+3+3/4=.75, 3 still keeps it in this voting algorithm, arg.
  def test_cast_vote_mary
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login("dick")
    obs.change_vote(nam2, 3, dick)
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)
    assert_equal(11, dick.reload.contribution)

    login("mary")
    post(:cast_vote, value: Vote.delete_vote, id: nam1.id)
    assert_equal(9, mary.reload.contribution)

    # Check votes.
    assert_equal(2, nam1.reload.vote_sum)
    assert_equal(1, nam1.votes.length)
    assert_equal(3, nam2.reload.vote_sum)
    assert_equal(3, nam2.votes.length)

    # Make sure observation is changed correctly.
    assert_equal(names(:coprinus_comatus).search_name,
      obs.reload.name.search_name,
      "Cache for 3: #{nam1.vote_cache}, 9: #{nam2.vote_cache}")
  end

  def test_show_votes
    # First just make sure the page displays.
    get_with_dump(:show_votes, id: namings(:coprinus_comatus_naming).id)
    assert_template(:show_votes, partial: "_show_votes")

    # Now try to make somewhat sure the content is right.
    table = namings(:coprinus_comatus_naming).calc_vote_table
    str1 = Vote.confidence(votes(:coprinus_comatus_owner_vote).value)
    str2 = Vote.confidence(votes(:coprinus_comatus_other_vote).value)
    for str in table.keys
      if str == str1 && str1 == str2
        assert_equal(2, table[str][:num])
      elsif str == str1
        assert_equal(1, table[str][:num])
      elsif str == str2
        assert_equal(1, table[str][:num])
      else
        assert_equal(0, table[str][:num])
      end
    end
  end

  # -----------------------------------
  #  Test extended observation forms.
  # -----------------------------------

  def test_javascripty_name_reasons
    login("rolf")

    # If javascript isn't enabled, then checkbox isn't required.
    post(:create_observation,
      observation: { place_name: 'Where, Japan', when: Time.now },
      name: { name: names(:coprinus_comatus).text_name },
      vote: { value: 3 },
      reason: {
        "1" => { check: "0", notes: ""    },
        "2" => { check: "0", notes: "foo" },
        "3" => { check: "1", notes: ""    },
        "4" => { check: "1", notes: "bar" }
      }
    )
    assert_response(:redirect) # redirected = successfully created
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.get_reasons.select(&:used?).map(&:num).sort
    assert_equal([2,3,4], reasons)

    # If javascript IS enabled, then checkbox IS required.
    post(:create_observation,
      observation: { place_name: 'Where, Japan', when: Time.now },
      name: { name: names(:coprinus_comatus).text_name },
      vote: { value: 3 },
      reason: {
        "1" => { check: "0", notes: ""    },
        "2" => { check: "0", notes: "foo" },
        "3" => { check: "1", notes: ""    },
        "4" => { check: "1", notes: "bar" }
      },
      was_js_on: "yes"
    )
    assert_response(:redirect) # redirected = successfully created
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.get_reasons.select(&:used?).map(&:num).sort
    assert_equal([3,4], reasons)
  end

  def test_create_with_image_upload
    login("rolf")

    time0 = Time.utc(2000)
    time1 = Time.utc(2001)
    time2 = Time.utc(2002)
    time3 = Time.utc(2003)
    week_ago = 1.week.ago

    setup_image_dirs
    file = "#{::Rails.root.to_s}/test/images/Coprinus_comatus.jpg"
    file1 = Rack::Test::UploadedFile.new(file, "image/jpeg")
    file2 = Rack::Test::UploadedFile.new(file, "image/jpeg")
    file3 = Rack::Test::UploadedFile.new(file, "image/jpeg")

    new_image_1 = Image.create(
      copyright_holder: "holder_1",
      when: time1,
      notes: "notes_1",
      user_id: 1,
      image: file1,
      content_type: 'image/jpeg',
      created_at: week_ago,
      # updated_at: week_ago
    )

    new_image_2 = Image.create(
      copyright_holder: "holder_2",
      when: time2,
      notes: "notes_2",
      user_id: 1,
      image: file2,
      content_type: 'image/jpeg',
      created_at: week_ago,
      # updated_at: week_ago
    )

    # assert(new_image_1.updated_at < 1.day.ago)
    # assert(new_image_2.updated_at < 1.day.ago)
    post(:create_observation,
      observation: {
        place_name: 'Zzyzx, Japan',
        when: time0,
        thumb_image_id: 0,   # (make new image the thumbnail)
        notes: "blah"
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
        new_image_1.id.to_s => {
        },
        new_image_2.id.to_s => {
          notes: "notes_2_new",
        }
      },
      # (attach these two images once observation created)
      good_images: "#{new_image_1.id} #{new_image_2.id}"
    )
    assert_response(:redirect) # redirected = successfully created

    obs = Observation.find_by_where('Zzyzx, Japan')
    assert_equal(1, obs.user_id)
    assert_equal(time0, obs.when)
    assert_equal('Zzyzx, Japan', obs.place_name)

    new_image_1.reload
    new_image_2.reload
    imgs = obs.images.sort_by(&:id)
    img_ids = imgs.map(&:id)
    assert_equal([new_image_1.id, new_image_2.id, new_image_2.id+1], img_ids)
    assert_equal(new_image_2.id+1, obs.thumb_image_id)
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

    post(:create_observation,
      observation: {
        place_name: "",  # will cause failure
        when: Time.now,
      },
      image: { "0" => {
        image: file,
        copyright_holder: "zuul",
        when: Time.now,
      }}
    )
    assert_response(:success) # success = failure, paradoxically

    # Make sure image was created, but that it is unattached, and that it has
    # been kept in the @good_images array for attachment later.
    img = Image.find_by_copyright_holder("zuul")
    assert(img)
    assert_equal([], img.observations)
    assert_equal([img.id],
      @controller.instance_variable_get('@good_images').map(&:id))
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
      name: {name: 'Screwy Name'},    # (ensures it will fail)
      project: {"id_#{@proj1.id}" => "0"}
    )
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)
  end

  def test_project_checkboxes_in_edit_observation
    init_for_project_checkbox_tests

    login("rolf")
    get(:edit_observation, id: @obs1.id)
    assert_response(:redirect)
    get(:edit_observation, id: @obs2.id)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
    post(:edit_observation, id: @obs2.id,
      observation: { place_name: "blah blah blah" },  # (ensures it will fail)
      project: { "id_#{@proj1.id}" => "1" }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    post(:edit_observation, id: @obs2.id,
      project: { "id_#{@proj1.id}" => "1" }
    )
    assert_response(:redirect)
    assert_obj_list_equal([@proj1], @obs2.reload.projects)
    assert_obj_list_equal([@proj1], @img2.reload.projects)

    login("mary")
    get(:edit_observation, id: @obs2.id)
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    get(:edit_observation, id: @obs1.id)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :checked)
    post(:edit_observation, id: @obs1.id,
      observation: { place_name: 'blah blah blah' },  # (ensures it will fail)
      project: {
        "id_#{@proj1.id}" => "1",
        "id_#{@proj2.id}" => "0",
      }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :unchecked)
    post(:edit_observation, id: @obs1.id,
      project: {
        "id_#{@proj1.id}" => "1",
        "id_#{@proj2.id}" => "1",
      }
    )
    assert_response(:redirect)
    assert_obj_list_equal([@proj1, @proj2], @obs1.reload.projects.sort_by(&:id))
    assert_obj_list_equal([@proj1, @proj2], @img1.reload.projects.sort_by(&:id))

    login("dick")
    get(:edit_observation, id: @obs2.id)
    assert_response(:redirect)
    get(:edit_observation, id: @obs1.id)
    assert_project_checks(@proj1.id => :checked_but_disabled,
                          @proj2.id => :checked)
  end

  def init_for_project_checkbox_tests
    @proj1 = projects(:eol_project)
    @proj2 = projects(:bolete_project)
    @obs1 = observations(:detailed_unknown)
    @obs2 = observations(:coprinus_comatus_obs)
    @img1 = @obs1.images.first
    @img2 = @obs2.images.first
    assert_users_equal(mary, @obs1.user)
    assert_users_equal(rolf, @obs2.user)
    assert_users_equal(mary, @img1.user)
    assert_users_equal(rolf, @img2.user)
    assert_obj_list_equal([@proj2], @obs1.projects)
    assert_obj_list_equal([], @obs2.projects)
    assert_obj_list_equal([@proj2], @img1.projects)
    assert_obj_list_equal([], @img2.projects)
    assert_obj_list_equal([rolf, mary, katrina], @proj1.user_group.users)
    assert_obj_list_equal([dick], @proj2.user_group.users)
  end

  def assert_project_checks(project_states)
    for id, state in project_states
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
      name: {name: 'Screwy Name'},    # (ensures it will fail)
      list: {"id_#{@spl2.id}" => "0"}
    )
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)
  end

  def test_list_checkboxes_in_edit_observation
    init_for_list_checkbox_tests

    login("rolf")
    get(:edit_observation, id: @obs1.id)
    assert_list_checks(@spl1.id => :unchecked, @spl2.id => :no_field)
    post(:edit_observation, id: @obs1.id,
      observation: { place_name: 'blah blah blah' },  # (ensures it will fail)
      list: { "id_#{@spl1.id}" => "1" }
    )
    assert_list_checks(@spl1.id => :checked, @spl2.id => :no_field)
    post(:edit_observation, id: @obs1.id,
      list: { "id_#{@spl1.id}" => "1" }
    )
    assert_response(:redirect)
    assert_obj_list_equal([@spl1], @obs1.reload.species_lists)
    get(:edit_observation, id: @obs2.id)
    assert_response(:redirect)

    login("mary")
    get(:edit_observation, id: @obs1.id)
    assert_response(:redirect)
    get(:edit_observation, id: @obs2.id)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :checked)
    @spl1.add_observation(@obs2)
    get(:edit_observation, id: @obs2.id)
    assert_list_checks(@spl1.id => :checked_but_disabled, @spl2.id => :checked)

    login("dick")
    get(:edit_observation, id: @obs2.id)
    assert_list_checks(@spl1.id => :checked_but_disabled, @spl2.id => :checked)
  end

  def init_for_list_checkbox_tests
    @spl1 = species_lists(:first_species_list)
    @spl2 = species_lists(:unknown_species_list)
    @obs1 = observations(:coprinus_comatus_obs)
    @obs2 = observations(:detailed_unknown)
    assert_users_equal(rolf, @spl1.user)
    assert_users_equal(mary, @spl2.user)
    assert_users_equal(rolf, @obs1.user)
    assert_users_equal(mary, @obs2.user)
    assert_obj_list_equal([], @obs1.species_lists)
    assert_obj_list_equal([@spl2], @obs2.species_lists)
  end

  def assert_list_checks(list_states)
    for id, state in list_states
      assert_checkbox_state("list_id_#{id}", state)
    end
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  def test_interest_in_show_observation
    login("rolf")
    minimal_unknown = observations(:minimal_unknown)

    # No interest in this observation yet.
    get(:show_observation, id: minimal_unknown.id)
    assert_response(:success)
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>[\w\s]*/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 1
    )
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>[\w\s]*/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: -1
    )

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.create(target: minimal_unknown, user: rolf, state: true)
    get(:show_observation, id: minimal_unknown.id)
    assert_response(:success)
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 0
    )
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: -1
    )

    # Destroy that interest, create new one with interest off.
    Interest.where(user_id: rolf.id).last.destroy
    Interest.create(target: minimal_unknown, user: rolf, state: false)
    get(:show_observation, id: minimal_unknown.id)
    assert_response(:success)
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 0
    )
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>/,
      controller: :interest, action: :set_interest,
      type: "Observation", id: minimal_unknown.id, state: 1
    )
  end

  # ----------------------------
  #  Lookup name.
  # ----------------------------

  def test_lookup_name
    get(:lookup_comment, id: 1)
    assert_redirected_to(controller: :comment, action: :show_comment, id: 1)
    get(:lookup_comment, id: 10000)
    assert_redirected_to(controller: :comment, action: :index_comment)
    assert_flash_error

    get(:lookup_image, id: 1)
    assert_redirected_to(controller: :image, action: :show_image, id: 1)
    get(:lookup_image, id: 10000)
    assert_redirected_to(controller: :image, action: :index_image)
    assert_flash_error

    get(:lookup_location, id: 1)
    assert_redirected_to(controller: :location, action: :show_location, id: 1)
    get(:lookup_location, id: "Burbank, California")
    assert_redirected_to(controller: :location, action: :show_location,
                         id: locations(:burbank).id)
    get(:lookup_location, id: "California, Burbank")
    assert_redirected_to(controller: :location, action: :show_location,
                         id: locations(:burbank).id)
    get(:lookup_location, id: 'Zyzyx, Califonria')
    assert_redirected_to(controller: :location, action: :index_location)
    assert_flash_error
    get(:lookup_location, id: "California")
    # assert_redirected_to(controller: :location, action: :index_location)
    assert_redirected_to(%r{/location/index_location})
    assert_flash_warning

    get(:lookup_name, id: 1)
    assert_redirected_to(controller: :name, action: :show_name, id: 1)
    get(:lookup_name, id: names(:coprinus_comatus).id)
    # assert_redirected_to(controller: :name, action: :show_name,
    #                      id: names(:coprinus_comatus).id)
    assert_redirected_to(%r{/name/show_name/#{names(:coprinus_comatus).id}})
    get(:lookup_name, id: "Agaricus campestris")
    assert_redirected_to(controller: :name, action: :show_name,
                         id: names(:agaricus_campestris).id)
    get(:lookup_name, id: 'Agaricus newname')
    assert_redirected_to(controller: :name, action: :index_name)
    assert_flash_error
    get(:lookup_name, id: 'Amanita baccata sensu Borealis')
    assert_redirected_to(controller: :name, action: :show_name,
                         id: names(:amanita_baccata_borealis).id)
    get(:lookup_name, id: 'Amanita baccata')
    # assert_redirected_to(controller: :name, action: :index_name)
    assert_redirected_to(%r{/name/index_name})
    assert_flash_warning
    get(:lookup_name, id: 'Agaricus campestris L.')
    assert_redirected_to(controller: :name, action: :show_name,
                         id: names(:agaricus_campestris).id)
    get(:lookup_name, id: 'Agaricus campestris Linn.')
    assert_redirected_to(controller: :name, action: :show_name,
                                     id: names(:agaricus_campestris).id)

    get(:lookup_project, id: 1)
    assert_redirected_to(controller: :project, action: :show_project, id: 1)
    get(:lookup_project, id: "Bolete")
    assert_redirected_to(controller: :project, action: :show_project,
                         id: projects(:bolete_project).id)
    get(:lookup_project, id: "Bogus")
    assert_redirected_to(controller: :project, action: :index_project)
    assert_flash_error
    get(:lookup_project, id: "project")
    # assert_redirected_to(controller: :project, action: :index_project)
    assert_redirected_to(%r{/project/index_project})
    assert_flash_warning

    get(:lookup_species_list, id: 1)
    assert_redirected_to(controller: :species_list, action: :show_species_list,
                         id: 1)
    get(:lookup_species_list, id: "Mysteries")
    assert_redirected_to(controller: :species_list, action: :show_species_list,
                         id: species_lists(:unknown_species_list).id)
    get(:lookup_species_list, id: "species list")
    # assert_redirected_to(controller: :species_list, action: :index_species_list)
    assert_redirected_to(%r{/species_list/index_species_list})
    assert_flash_warning
    get(:lookup_species_list, id: "Flibbertygibbets")
    assert_redirected_to(controller: :species_list, action: :index_species_list)
    assert_flash_error

    get(:lookup_user, id: 1)
    assert_redirected_to(controller: :observer, action: :show_user, id: 1)
    get(:lookup_user, id: "mary")
    assert_redirected_to(controller: :observer, action: :show_user, id: mary.id)
    get(:lookup_user, id: "Einstein")
    assert_redirected_to(controller: :observer, action: :index_rss_log)
    assert_flash_error
  end

  def test_change_banner
    use_test_locales {
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
                                       text: 'banner ancienne',
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

      post(:change_banner, val: 'new banner')
      assert_no_flash
      assert_redirected_to(action: :list_rss_logs)
      assert_equal('new banner', :app_banner_box.l)

      strs = TranslationString.where(tag: :app_banner_box)
      for str in strs
        assert_equal("new banner",
          str.text, "Didn't change text of #{str.language.locale} correctly.")
      end
    }
  end

  def test_index_observation_by_past_by
    get(:index_observation, by: :modified)
    assert_response(:success)
    get(:index_observation, by: :created)
    assert_response(:success)
  end

  def test_download_observation_index
    obs = Observation.where(user_id: mary.id)
    assert(4 <= obs.length)
    query = Query.lookup_and_save(:Observation, :by_user, user: mary.id)

    get(:download_observations, q: query.id.alphabetize)
    assert_no_flash
    assert_response(:success)

    post(:download_observations, q: query.id.alphabetize, format: :raw,
        encoding: 'UTF-8', commit: "Cancel")
    assert_no_flash
    # assert_redirected_to(action: :index_observation)
    assert_redirected_to(%r{/index_observation})

    post(:download_observations, q: query.id.alphabetize, format: :raw,
        encoding: "UTF-8", commit: "Download")
        rows = @response.body.split("\n")
    ids = rows.map { |s| s.sub(/,.*/, "") }
    expected = ["observation_id", "1", "2", "9", "10"]
    last_expected_index = expected.length - 1

    assert_no_flash
    assert_response(:success)
    assert_equal(expected, ids[0..last_expected_index],
      "Exported 1st column incorrect")
    fourth_row = rows[last_expected_index].chop
    assert_equal(
      "10,2,mary,Mary Newbie,2010-07-22,,1,Fungi,,Kingdom,0.0,2," \
        "USA,California,,Burbank," \
        "34.1622,-118.3521,,34.22,34.15,-118.29,-118.37,294,148,X,",
      fourth_row.iconv('utf-8'), "Exported 4th row incorrect"
    )

    post(:download_observations, q: query.id.alphabetize, format: "raw",
        encoding: "ASCII", commit: "Download")
    assert_no_flash
    assert_response(:success)

    post(:download_observations, q: query.id.alphabetize, format: "raw",
        encoding: 'UTF-16', commit: "Download")
    assert_no_flash
    assert_response(:success)

    post(:download_observations, q: query.id.alphabetize, format: "adolf",
        encoding: 'UTF-8', commit: "Download")
    assert_no_flash
    assert_response(:success)

    post(:download_observations, q: query.id.alphabetize, format: "darwin",
        encoding: 'UTF-8', commit: "Download")
    assert_no_flash
    assert_response(:success)

    post(:download_observations, q: query.id.alphabetize, format: "symbiota",
        encoding: 'UTF-8', commit: "Download")
    assert_no_flash
    assert_response(:success)
  end
end
