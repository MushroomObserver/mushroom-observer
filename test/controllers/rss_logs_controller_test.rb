# frozen_string_literal: true

require("test_helper")

class RssLogsControllerTest < FunctionalTestCase
  def test_page_loads
    get(:index)
    assert_redirected_to(new_account_login_path)

    login
    get(:index)
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

    # Show all via q param
    get(:index, params: { q: { type: "all" } })
    assert_template(:index)

    get(:index, params: { q: { type: %w[article glossary_term] } })
    assert_template(:index)

    get(:index, params: { q: { type: [] } })
    assert_template(:index)

    # Old-style top level :type param now redirects
    get(:index, params: { type: "all" })
    assert_response(:redirect)

    get(:index, params: { type: %w[article glossary_term] })
    assert_response(:redirect)
  end

  def test_get_index_rss_log
    # With q[type], it should display only that type
    expect = rss_logs(:glossary_term_rss_log)
    login
    get(:index, params: { q: { type: "glossary_term" } })
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
    get(:index, params: { q: { model: "RssLog", type: "glossary_term" },
                          make_default: 1 })
    assert_equal("glossary_term", rolf.reload.default_rss_type)
    # Test that this actually works
    q = @controller.q_param(QueryRecord.last.query)
    get(:index, params: { q: q })
    assert_template(:index)
  end

  # Prove that user content_filter works on rss_log
  def test_rss_log_has_specimen_content_filter
    login(users(:vouchered_only_user).name)
    get(:index, params: { q: { type: "observation" } })
    results = @controller.instance_variable_get(:@objects)

    assert(results.exclude?(rss_logs(:imged_unvouchered_obs_rss_log)))
    assert(results.include?(rss_logs(:detailed_unknown_obs_rss_log)))
  end

  def test_rss_log_lichen_content_filter
    login(users(:lichenologist).name)
    get(:index, params: { q: { type: "observation" } })
    results = @controller.instance_variable_get(:@objects)

    assert(results.exclude?(rss_logs(:imged_unvouchered_obs_rss_log)))
    assert(results.include?(rss_logs(:peltigera_obs_rss_log)))

    login(users(:antilichenologist).name)
    get(:index, params: { q: { type: "observation" } })
    results = @controller.instance_variable_get(:@objects)

    assert(results.exclude?(rss_logs(:peltigera_obs_rss_log)))
    assert(results.include?(rss_logs(:stereum_hirsutum_2_rss_log)))
  end

  def test_rss_log_region_content_filter
    login(users(:californian).name)
    get(:index, params: { q: { type: "observation" } })
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
    get(:index, params: { q: { type: "observation" } })

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
    get(:index, params: { q: { type: "observation" } })

    assert_includes(@response.body, obs.source_credit.tpl,
                    "RssLog is missing Source credit")
  end

  def test_type_filter_rejects_invalid_types
    login

    # Invalid type string via q param should be sanitized to "none"
    get(:index, params: { q: { model: "RssLog",
                               type: "bad_code; DROP TABLE users;" } })
    assert_template(:index)
    types = @controller.instance_variable_get(:@types)
    assert_equal(["none"], types)

    # Mixed valid and invalid types (string) - only valid ones kept
    get(:index, params: { q: { model: "RssLog",
                               type: "observation bad_stuff name" } })
    assert_template(:index)
    types = @controller.instance_variable_get(:@types)
    # Order preserved from input
    assert_equal(%w[name observation], types)

    # All invalid types via q param string
    get(:index, params: { q: { model: "RssLog", type: "evil<script>" } })
    assert_template(:index)
    types = @controller.instance_variable_get(:@types)
    assert_equal(["none"], types)

    # Invalid types in array format via q param
    get(:index, params: { q: { model: "RssLog",
                               type: %w[bad_code evil<script>] } })
    assert_template(:index)
    types = @controller.instance_variable_get(:@types)
    assert_equal(["none"], types)

    # Mixed valid and invalid in array format via q param
    get(:index, params: { q: { model: "RssLog",
                               type: %w[observation bad_stuff name] } })
    assert_template(:index)
    types = @controller.instance_variable_get(:@types)
    assert_equal(%w[name observation], types)
  end

  def test_type_filter_form_submits_as_array
    login

    # Simulate form submission with type checkboxes as array under q param
    # Form submits q[type][]=observation&q[type][]=name
    get(:index, params: {
          q: { model: "RssLog", type: %w[observation name] }
        })
    assert_template(:index)
    types = @controller.instance_variable_get(:@types)
    # Check both types are present (order may vary)
    assert_includes(types, "observation")
    assert_includes(types, "name")
  end

  def test_old_style_type_param_redirects_to_q_param
    login

    # Old-style string type param should redirect to q param URL
    get(:index, params: { type: "observation" })
    assert_response(:redirect)
    assert_match(/q%5Bmodel%5D=RssLog/, @response.location)
    assert_match(/q%5Btype%5D=observation/, @response.location)

    # Old-style array type param should redirect to q param URL
    get(:index, params: { type: %w[glossary_term article] })
    assert_response(:redirect)
    # Should contain both types (order may vary)
    assert_match(/q%5Bmodel%5D=RssLog/, @response.location)
    assert_match(/q%5Btype%5D=/, @response.location)
    assert_match(/glossary_term/, @response.location)
    assert_match(/article/, @response.location)

    # Invalid type should redirect with "none"
    get(:index, params: { type: "evil<script>" })
    assert_response(:redirect)
    assert_match(/q%5Btype%5D=none/, @response.location)

    # Non-string/non-array type (e.g., hash) should redirect with "all"
    get(:index, params: { type: { weird: "hash" } })
    assert_response(:redirect)
    assert_match(/q%5Btype%5D=all/, @response.location)
  end

  def test_type_filter_preserves_other_query_params
    login

    # First, create a query with additional params (order_by)
    get(:index, params: { q: { model: "RssLog", type: "observation",
                               order_by: "created_at" } })
    assert_template(:index)
    query = QueryRecord.last.query
    assert_equal("observation", query.params[:type])
    assert_equal("created_at", query.params[:order_by])

    # Now change type filter - order_by should be preserved
    get(:index, params: { q: { model: "RssLog", type: "name",
                               order_by: "created_at" } })
    assert_template(:index)
    query = QueryRecord.last.query
    assert_equal("name", query.params[:type])
    assert_equal("created_at", query.params[:order_by],
                 "order_by should be preserved when changing type filter")
  end

  def test_type_filter_links_have_no_duplicate_params
    login

    get(:index, params: { q: { model: "RssLog", type: "observation" } })
    assert_template(:index)

    # Check that the filter links don't have duplicate q[model] or q[type]
    body = @response.body

    # Find all href attributes containing activity_logs
    hrefs = body.scan(/href="([^"]*activity_logs[^"]*)"/).flatten

    hrefs.each do |href|
      decoded = CGI.unescape(href)
      # Count occurrences of q[model] and q[type]
      model_count = decoded.scan("q[model]").length
      type_count = decoded.scan("q[type]").length

      assert_operator(model_count, :<=, 1,
                      "URL has duplicate q[model]: #{decoded}")
      assert_operator(type_count, :<=, 1,
                      "URL has duplicate q[type]: #{decoded}")
    end
  end
end
