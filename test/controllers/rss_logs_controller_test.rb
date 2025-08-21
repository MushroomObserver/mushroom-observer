# frozen_string_literal: true

require("test_helper")

class RssLogsControllerTest < FunctionalTestCase
  def test_page_loads
    get(:index)
    assert_redirected_to(new_account_login_path)

    login
    get(:index)
    assert_template("shared/_matrix_box")
    assert_link_in_html(:app_intro.t, info_intro_path)

    get(:rss)
    assert_template(:rss)

    get(:show, params: { id: rss_logs(:detailed_unknown_obs_rss_log).id })
    assert_template(:show)
  end

  def test_rss_with_article_in_feed
    login("rolf")
    article = Article.create!(title: "Really _Neat_ Feature!",
                              body: "Does stuff.")
    assert_equal("Really Neat Feature!", article.text_name)
    get(:rss)
  end

  def test_altering_types_shown_by_rss_log_index
    login
    # Show none.
    post(:index)
    assert_template(:index)

    # Show all.
    params = {}
    params[:type] = RssLog::ALL_TYPE_TAGS

    post(:index, params: params)
    assert_template(:index)

    # Be sure "all" loads some rss_logs!
    get(:index, params: { type: "all" })
    assert_template("shared/_matrix_box")

    get(:index, params: { type: [:article, :glossary_term] })
    assert_template(:index)

    get(:index, params: { type: [] })
    assert_template(:index)
  end

  def test_get_index_rss_log
    # With params[:type], it should display only that type
    expect = rss_logs(:glossary_term_rss_log)
    login
    get(:index, params: { type: :glossary_term })
    assert_match(/#{expect.glossary_term.name}/, css_select(".rss-what").text)
    assert_no_match(
      /#{rss_logs(:detailed_unknown_obs_rss_log).observation.name}/,
      css_select(".rss-what").text
    )

    # Without params[:type], it should display all logs
    get(:index)
    assert_match(/#{expect.glossary_term.name}/, css_select(".rss-what").text)
    assert_match(
      /#{rss_logs(:detailed_unknown_obs_rss_log).observation.name.text_name}/,
      css_select(".rss-what").text
    )

    comments_for_path = comments_path(for_user: User.current_id)
    assert_select(
      "a[href='#{comments_for_path}']",
      true, "LH NavBar 'Commments for` link broken"
    )
  end

  def test_user_default_rss_log
    # Prove that user can change his default rss log type.
    login("rolf")
    get(:index, params: { type: :glossary_term, make_default: 1 })
    assert_equal("glossary_term", rolf.reload.default_rss_type)
    # Test that this actually works
    q = @controller.full_q_param(QueryRecord.last.query)
    get(:index, params: { q: q })
    assert_template(:index)
  end

  # Prove that user content_filter works on rss_log
  def test_rss_log_has_specimen_content_filter
    login(users(:vouchered_only_user).name)
    get(:index, params: { type: :observation })
    results = @controller.instance_variable_get(:@objects)

    assert(results.exclude?(rss_logs(:imged_unvouchered_obs_rss_log)))
    assert(results.include?(rss_logs(:detailed_unknown_obs_rss_log)))
  end

  def test_rss_log_lichen_content_filter
    login(users(:lichenologist).name)
    get(:index, params: { type: :observation })
    results = @controller.instance_variable_get(:@objects)

    assert(results.exclude?(rss_logs(:imged_unvouchered_obs_rss_log)))
    assert(results.include?(rss_logs(:peltigera_obs_rss_log)))

    login(users(:antilichenologist).name)
    get(:index, params: { type: :observation })
    results = @controller.instance_variable_get(:@objects)

    assert(results.exclude?(rss_logs(:peltigera_obs_rss_log)))
    assert(results.include?(rss_logs(:stereum_hirsutum_2_rss_log)))
  end

  def test_rss_log_region_content_filter
    login(users(:californian).name)
    get(:index, params: { type: :observation })
    results = @controller.instance_variable_get(:@objects)

    assert(results.exclude?(rss_logs(:unknown_with_no_naming_rss_log)))
    assert(results.include?(rss_logs(:minimal_unknown_obs_rss_log)))
  end

  def test_next_and_prev_rss_log
    # First 2 log entries
    logs = RssLog.order(updated_at: :desc).limit(2)
    login
    get(:show, params: { flow: "next", id: logs.first })
    # assert_redirected_to does not work here because #next redirects to a url
    # which includes a query after the id, but assert_redirected_to treats
    # the query as part of the id.
    assert_response(:redirect)
    assert_match(activity_log_path(logs.second.id),
                 @response.header["Location"], "Redirected to wrong page")

    get(:show, params: { flow: "prev", id: logs.second })
    assert_response(:redirect)
    assert_match(activity_log_path(logs.first.id),
                 @response.header["Location"], "Redirected to wrong page")
  end

  def test_missing_rss_log
    log = RssLog.order(id: :desc).first
    missing_id = log.id + 1
    login
    get(:show, params: { flow: "prev", id: missing_id })
    assert_response(:redirect)
    assert_match(activity_logs_path,
                 @response.header["Location"], "Redirected to wrong page")
  end

  def test_rss_log_display_source_credit
    obs = observations(:imported_inat_obs)

    login
    get(:index, params: { type: :observation })

    assert_includes(@response.body, obs.source_credit.tpl,
                    "RssLog is missing Source credit")
  end

  def test_rss_log_display_source_credit_updated_observation
    obs = observations(:imported_inat_obs)
    time = Time.now.utc
    obs.update(updated_at: time, log_updated_at: time)
    log = rss_logs(:imported_inat_obs_rss_log)
    log.update(updated_at: time,
               notes: "log_observation_updated user dick\n" \
                      "log_observation_created user dick\n")

    login
    get(:index, params: { type: :observation })

    assert_includes(@response.body, obs.source_credit.tpl,
                    "RssLog is missing Source credit")
  end
end
