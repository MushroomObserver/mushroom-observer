# frozen_string_literal: true

require "test_helper"

class RssLogsControllerTest < FunctionalTestCase

  # NOTE: this was moved from ObservationsControllerTest#test_page_loads
  def test_page_loads
    get(:index)
    assert_template(
      :index,
      partial: :_log_item
    )

    get(:rss)
    assert_template(:rss)

    get(:show, id: rss_logs(:observation_rss_log).id)
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
    get(:index_rss_log, params: { type: :glossary_term })
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

  def test_change_banner # NOTE: this is in the RssLogsController now
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

end
