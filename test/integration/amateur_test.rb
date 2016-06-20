# encoding: utf-8
# Test typical sessions of amateur user who just posts the occasional comment,
# observations, or votes.

require "test_helper"

class AmateurTest < IntegrationTestCase
  # -------------------------------
  #  Test basic login heuristics.
  # -------------------------------

  def test_login
    # Start at index.
    get("/")
    save_path = path

    # Login.
    click(label: "Login", in: :left_panel)
    assert_template("account/login")

    # Try to login without a password.
    open_form do |form|
      form.assert_value("login", "")
      form.assert_value("password", "")
      form.assert_checked("remember_me")
      form.change("login", "rolf")
      form.submit("Login")
    end
    assert_template("account/login")
    assert_flash(/unsuccessful/i)

    # Try again with incorrect password.
    open_form do |form|
      form.assert_value("login", "rolf")
      form.assert_value("password", "")
      form.assert_checked("remember_me", false)
      form.change("password", "boguspassword")
      form.submit("Login")
    end
    assert_template("account/login")
    assert_flash(/unsuccessful/i)

    # Try yet again with correct password.
    open_form do |form|
      form.assert_value("login", "rolf")
      form.assert_value("password", "")
      form.assert_checked("remember_me", false)
      form.change("password", "testpassword")
      form.submit("Login")
    end
    assert_template("observer/list_rss_logs")
    assert_flash(/success/i)

    # This should only be accessible if logged in.
    click(label: "Preferences", in: :left_panel)
    assert_template("account/prefs")

    # Log out and try again.
    click(label: "Logout", in: :left_panel)
    assert_template("account/logout_user")
    assert_raises(MiniTest::Assertion) do
      click(label: "Preferences", in: :left_panel)
    end
    get("/account/prefs")
    assert_template("account/login")
  end

  # ----------------------------
  #  Test autologin cookies.
  # ----------------------------

  def test_autologin
    rolf_cookies = get_cookies(rolf, :true)
    mary_cookies = get_cookies(mary, true)
    dick_cookies = get_cookies(dick, false)

    try_autologin(rolf_cookies, rolf)
    try_autologin(mary_cookies, mary)
    try_autologin(dick_cookies, false)
  end

  def get_cookies(user, autologin)
    sess = login(user, "testpassword", autologin)
    result = sess.cookies.dup
    if autologin
      assert_match(/^#{user.id}/, result["mo_user"])
    else
      assert_equal("", result["mo_user"].to_s)
    end
    result
  end

  def try_autologin(cookies, user)
    open_session do |sess|
      sess.cookies["mo_user"] = cookies["mo_user"]
      sess.get("/account/prefs")
      if user
        sess.assert_template("account/prefs")
        assert_users_equal(user, sess.assigns(:user))
      else
        sess.assert_template("account/login")
      end
    end
  end

  # ----------------------------------
  #  Test everything about comments.
  # ----------------------------------

  def test_post_comment
    obs = observations(:detailed_unknown_obs)
    # (Make sure Katrina doesn't own any comments on this observation yet.)
    assert_false(obs.comments.any? { |c| c.user == katrina })

    summary = "Test summary"
    message = "This is a big fat test!"
    message2 = "This may be _Xylaria polymorpha_, no?"

    # Start by showing the observation...
    get("/#{obs.id}")

    # (Make sure there are no edit or destroy controls on existing comments.)
    assert_select("a[href*=edit_comment], a[href*=destroy_comment]", false)

    click(label: "Add Comment")
    assert_template("account/login")
    login("katrina")
    assert_template("comment/add_comment")

    # (Make sure the form is for the correct object!)
    assert_objs_equal(obs, assigns(:target))
    # (Make sure there is a tab to go back to show_observation.)
    assert_select("div#right_tabs a[href='/#{obs.id}']")

    open_form(&:submit)
    assert_template("comment/add_comment")
    # (I don't care so long as it says something.)
    assert_flash(/\S/)

    open_form do |form|
      form.change("summary", summary)
      form.change("comment", message)
      form.submit
    end
    assert_template("observer/show_observation")
    assert_objs_equal(obs, assigns(:observation))

    com = Comment.last
    assert_equal(summary, com.summary)
    assert_equal(message, com.comment)

    # (Make sure comment shows up somewhere.)
    assert_match(summary, response.body)
    assert_match(message, response.body)
    # (Make sure there is an edit and destroy control for the new comment.)
    assert_select("a[href*='edit_comment/#{com.id}']", 1)
    assert_select("a[href*='destroy_comment/#{com.id}']", 1)

    # Try changing it.
    click(label: /edit/i, href: /edit_comment/)
    assert_template("comment/edit_comment")
    open_form do |form|
      form.assert_value("summary", summary)
      form.assert_value("comment", message)
      form.change("comment", message2)
      form.submit
    end
    assert_template("observer/show_observation")
    assert_objs_equal(obs, assigns(:observation))

    com.reload
    assert_equal(summary, com.summary)
    assert_equal(message2, com.comment)

    # (Make sure comment shows up somewhere.)
    assert_match(summary, response.body)
    assert(response.body.index(message2.tl))
    # (There should be a link in there to look up Xylaria polymorpha.)
    assert_select("a[href*=lookup_name]", 1) do |links|
      url = links.first.attributes["href"]
      assert_equal("#{MO.http_domain}/observer/lookup_name/Xylaria+polymorpha",
                   url.value)
    end

    # I grow weary of this comment.
    click(label: /destroy/i, href: /destroy_comment/)
    assert_template("observer/show_observation")
    assert_objs_equal(obs, assigns(:observation))
    assert_nil(response.body.index(summary))
    assert_select("a[href*=edit_comment], a[href*=destroy_comment]", false)
    assert_nil(Comment.safe_find(com.id))
  end

  # --------------------------------------
  #  Test proposing and voting on names.
  # --------------------------------------

  def test_proposing_names
    namer_session = open_session.extend(NamerDsl)
    namer = katrina

    obs = observations(:detailed_unknown_obs)
    # (Make sure Katrina doesn't own any comments on this observation yet.)
    assert_false(obs.comments.any? { |c| c.user == namer })
    # (Make sure the name we are going to suggest doesn't exist yet.)
    text_name = "Xylaria polymorpha"
    assert_nil(Name.find_by_text_name(text_name))
    orignal_name = obs.name

    namer_session.propose_then_login(namer, obs)
    naming = namer_session.create_name(obs, text_name)

    voter_session = login!(rolf).extend(VoterDsl)
    assert_not_equal(namer_session.session[:session_id], voter_session.session[:session_id])
    voter_session.vote_on_name(obs, naming)
    namer_session.failed_delete(obs)
    voter_session.change_mind(obs, naming)
    namer_session.successful_delete(obs, naming, text_name, orignal_name)
  end

  def test_sessions
    rolf_session = login!(rolf).extend(NamerDsl)
    mary_session = login!(mary).extend(VoterDsl)
    assert_not_equal(mary_session.session[:session_id], rolf_session.session[:session_id])
  end

  # ------------------------------------------------------------------------
  #  Quick test to try to catch a bug that the functional tests can't seem
  #  to catch.  (Functional tests can survive undefined local variables in
  #  partials, but not integration tests.)
  # ------------------------------------------------------------------------

  def test_edit_image
    login("mary")
    get("/image/edit_image/1")
  end

  # ------------------------------------------------------------------------
  #  Tests to make sure that the proper links are rendered  on the  home page
  #  when a user is logged in.
  #  test_user_dropdown_avaiable:: tests for existence of dropdown bar & links
  #
  # ------------------------------------------------------------------------

  def test_user_dropdown_avaiable
    session = login("dick")
    session.get("/")
    session.assert_select("li#user_drop_down")
    links = session.css_select("li#user_drop_down a")
    assert_equal(links.length, 7)
  end

  # -------------------------------------------------------------------------
  #  Need integration test to make sure session and actions are all working
  #  together correctly.
  # -------------------------------------------------------------------------

  def test_thumbnail_maps
    get("/#{observations(:minimal_unknown_obs).id}")
    assert_template("observer/show_observation")
    assert_select('div#map_div', 1)

    click(label: "Hide thumbnail map.")
    assert_template("observer/show_observation")
    assert_select('div#map_div', 0)

    session = login("dick")
    session.assert_template("observer/show_observation")
    session.assert_select('div#map_div', 1)

    session.click(label: "Hide thumbnail map.")
    session.assert_template("observer/show_observation")
    session.assert_select('div#map_div', 0)

    session.get("/#{observations(:detailed_unknown_obs).id}")
    session.assert_template("observer/show_observation")
    session.assert_select('div#map_div', 0)
  end

  # -----------------------------------------------------------------------
  #  Need intrgration test to make sure tags are being tracked and passed
  #  through redirects correctly.
  # -----------------------------------------------------------------------

  def test_language_tracking
    session = login(mary).extend(UserDsl)
    mary.locale = "el-GR"
    I18n.locale = mary.lang
    mary.save

    data = TranslationString.translations("el") # Globalite.localization_data[:'el-GR']
    data[:test_tag1] = "test_tag1 value"
    data[:test_tag2] = "test_tag2 value"
    data[:test_flash_redirection_title] = "Testing Flash Redirection"

    session.run_test
  end

  private

  module UserDsl
    def run_test
      get("/observer/test_flash_redirection?tags=")
      click(label: :app_edit_translations_on_page.t)
      assert_no_flash
      assert_select("span.tag", text: "test_tag1:", count: 0)
      assert_select("span.tag", text: "test_tag2:", count: 0)
      assert_select("span.tag", text: "test_flash_redirection_title:", count: 1)

      get("/observer/test_flash_redirection?tags=test_tag1,test_tag2")
      click(label: :app_edit_translations_on_page.t)
      assert_no_flash
      assert_select("span.tag", text: "test_tag1:", count: 1)
      assert_select("span.tag", text: "test_tag2:", count: 1)
      assert_select("span.tag", text: "test_flash_redirection_title:", count: 1)
    end
  end

  module VoterDsl
    def vote_on_name(obs, naming)
      get("/#{obs.id}")
      open_form("form[id=cast_votes_1]") do |form|
        form.assert_value("vote_#{naming.id}_value", /no opinion/i)
        form.select("vote_#{naming.id}_value", /call it that/i)
        form.submit
      end
      assert_template("observer/show_observation")
      assert_match(/call it that/i, response.body)
    end

    def change_mind(obs, naming)
      # "change_mind response.body".print_thing(response.body)
      get("/#{obs.id}")
      open_form("form[id=cast_votes_1]") do |form|
        form.select("vote_#{naming.id}_value", /as if!/i)
        form.submit
      end
    end
  end

  module NamerDsl
    def propose_then_login(namer, obs)
      get("/#{obs.id}")
      assert_select("a[href*='naming/edit'], a[href*='naming/destroy']", false)
      click(label: /propose.*name/i)
      assert_template("account/login")
      open_form do |form|
        form.change("login", namer.login)
        form.change("password", "testpassword")
        form.change("remember_me", true)
        form.submit("Login")
      end
    end

    def create_name(obs, text_name)
      assert_template("naming/create")
      # (Make sure the form is for the correct object!)
      assert_objs_equal(obs, assigns(:params).observation)
      # (Make sure there is a tab to go back to show_observation.)
      assert_select("div#right_tabs a[href='/#{obs.id}']")

      open_form do |form|
        form.assert_value("name_name", "")
        form.assert_value("vote_value", "")
        form.assert_checked("reason_1_check", false)
        form.assert_checked("reason_2_check", false)
        form.assert_checked("reason_3_check", false)
        form.assert_checked("reason_4_check", false)
        form.submit
      end
      assert_template("naming/create")
      # (I don't care so long as it says something.)
      assert_flash(/\S/)

      open_form do |form|
        form.change("name", text_name)
        form.submit
      end
      assert_template("naming/create")
      assert_select("div.alert-warning") do |elems|
        assert(elems.any? { |e| e.to_s.match(/#{text_name}.*not recognized/i) },
               "Expected error about name not existing yet.")
      end

      open_form(&:submit)
      assert_template("naming/create")
      assert_flash(/confidence/i)

      open_form do |form|
        form.assert_value("name", text_name)
        form.assert_checked("reason_1_check", false)
        form.assert_checked("reason_2_check", false)
        form.assert_checked("reason_3_check", false)
        form.assert_checked("reason_4_check", false)
        form.select(/vote/, /call it that/i)
        form.submit
      end
      assert_template("observer/show_observation")
      assert_flash(/success/i)
      assert_objs_equal(obs, assigns(:observation))

      obs.reload
      name = Name.find_by_text_name(text_name)
      naming = Naming.last
      assert_names_equal(name, naming.name)
      assert_names_equal(name, obs.name)
      assert_equal("", name.author.to_s)

      # (Make sure naming shows up somewhere.)
      assert_match(text_name, response.body)
      # (Make sure there is an edit and destroy control for the new naming.)
      # (Now two: one for wide-screen, one for mobile.)
      assert_select("a[href*='naming/edit/#{naming.id}']", 2)
      assert_select("a[href*='naming/destroy/#{naming.id}']", 2)

      # Try changing it.
      author = "(Pers.) Grev."
      reason = "Test reason."
      click(label: /edit/i, href: /naming\/edit/)
      assert_template("naming/edit")
      open_form do |form|
        form.assert_value("name", text_name)
        form.change("name", "#{text_name} #{author}")
        form.change("reason_2_check", true)
        form.change("reason_2_notes", reason)
        form.select("vote_value", /call it that/i)
        form.submit
      end
      assert_template("observer/show_observation")
      assert_objs_equal(obs, assigns(:observation))

      obs.reload
      name.reload
      naming.reload
      assert_equal(author, name.author)
      assert_names_equal(name, naming.name)
      assert_names_equal(name, obs.name)

      # (Make sure author shows up somewhere.)
      assert_match(author, response.body)
      # (Make sure reason shows up, too.)
      assert_match(reason, response.body)

      click(label: /edit/i, href: /naming\/edit/)
      assert_template("naming/edit")
      open_form do |form|
        form.assert_value("name", "#{text_name} #{author}")
        form.assert_checked("reason_1_check", false)
        form.assert_value("reason_1_notes", "")
        form.assert_checked("reason_2_check")
        form.assert_value("reason_2_notes", reason)
        form.assert_checked("reason_3_check", false)
        form.assert_value("reason_3_notes", "")
      end
      click(label: /cancel.*show/i)
      # "end create_name response.body".print_thing(response.body)
      naming
    end

    def failed_delete(_obs)
      # "failed_delete response.body".print_thing(response.body)
      click(label: /destroy/i, href: /naming\/destroy/)
      assert_flash(/sorry/i)
    end

    def successful_delete(obs, naming, text_name, original_name)
      # "successful_delete response.body".print_thing(response.body)
      click(label: /destroy/i, href: /naming\/destroy/)
      assert_template("observer/show_observation")
      assert_objs_equal(obs, assigns(:observation))
      assert_flash(/success/i)

      obs.reload
      assert_names_equal(original_name, obs.name)
      assert_nil(Naming.safe_find(naming.id))
      refute_match(text_name, response.body)
    end
  end
end
