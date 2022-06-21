# frozen_string_literal: true

class RssLogsControllerTest < FunctionalTestCase
  def test_page_loads
    login
    get_with_dump(:index)
    assert_template(:index, partial: :_rss_log)
    assert_link_in_html(:app_intro.t, controller: :observer, action: :intro)

    get_with_dump(:index)
    assert_template(:index, partial: :_rss_log)

    get_with_dump(:rss)
    assert_template(:rss)

    get_with_dump(:show, id: rss_logs(:observation_rss_log).id)
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

    # Show one.
    post(:index,
         params: { show_observations: observations(:minimal_unknown_obs).to_s })
    assert_template(:index)

    # Show all.
    params = {}
    RssLog.all_types.each { |type| params["show_#{type}"] = "1" }
    post(:index, params: params)
    assert_template(:index, partial: rss_logs(:observation_rss_log).id)
  end

  def test_get_index_rss_log
    # With params[:type], it should display only that type
    expect = rss_logs(:glossary_term_rss_log)
    login
    get(:index, params: { type: :glossary_term })
    assert_match(/#{expect.glossary_term.name}/, css_select(".rss-what").text)
    assert_no_match(/#{rss_logs(:observation_rss_log).observation.name}/,
                    css_select(".rss-what").text)

    # Without params[:type], it should display all logs
    get(:index)
    assert_match(/#{expect.glossary_term.name}/, css_select(".rss-what").text)
    assert_match(/#{rss_logs(:observation_rss_log).observation.name.text_name}/,
                 css_select(".rss-what").text)
  end

  def test_user_default_rss_log
    # Prove that MO offers to make non-default log the user's default.
    login("rolf")
    get(:index, params: { type: :glossary_term })
    link_text = @controller.instance_variable_get("@links").flatten.first
    assert_equal(:rss_make_default.l, link_text)

    # Prove that user can change his default rss log type.
    get(:index, params: { type: :glossary_term, make_default: 1 })
    assert_equal("glossary_term", rolf.reload.default_rss_type)
  end

  # Prove that user content_filter works on rss_log
  def test_rss_log_with_content_filter
    login(users(:vouchered_only_user).name)
    get(:index, params: { type: :observation })
    results = @controller.instance_variable_get("@objects")

    assert(results.exclude?(rss_logs(:imged_unvouchered_obs_rss_log)))
    assert(results.include?(rss_logs(:observation_rss_log)))
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

end