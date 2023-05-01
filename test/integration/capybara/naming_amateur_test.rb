# frozen_string_literal: true

require("test_helper")

class NamingAmateurTest < CapybaraIntegrationTestCase
  # --------------------------------------
  #  Test proposing and voting on names.
  # --------------------------------------

  def test_proposing_names
    namer_session = Capybara::Session.new(:rack_test, Rails.application)
    namer = katrina

    obs = observations(:detailed_unknown_obs)
    # (Make sure Katrina doesn't own any comments on this observation yet.)
    assert_false(obs.comments.any? { |c| c.user == namer })
    # (Make sure the name we are going to suggest doesn't exist yet.)
    text_name = "Xylaria polymorpha"
    assert_nil(Name.find_by(text_name: text_name))
    orignal_name = obs.name

    login(namer, session: namer_session)
    namer_session.assert_no_link(class: /edit_naming_link_/)
    namer_session.assert_no_selector(class: /destroy_naming_link_/)

    click_link(text: /propose.*name/)
    # naming = namer_session.create_name(obs, text_name)
    assert_selector("namings__new")
    # (Make sure the form is for the correct object!)
    binding.break
    assert_selector("form[action*='/comments?target=#{obs.id}']")
    assert_objs_equal(obs, assigns(:params).observation)
    # (Make sure there is a tab to go back to observations/show.)
    assert_select("#right_tabs a[href='/#{obs.id}']")

    open_form do |form|
      form.assert_value("naming_name", "")
      form.assert_value("naming_vote_value", "")
      form.assert_unchecked("naming_reasons_1_check")
      form.assert_unchecked("naming_reasons_2_check")
      form.assert_unchecked("naming_reasons_3_check")
      form.assert_unchecked("naming_reasons_4_check")
      form.submit
    end
    assert_template("observations/namings/new")
    # (I don't care so long as it says something.)
    assert_flash_text(/\S/)

    open_form do |form|
      form.change("naming_name", text_name)
      form.submit
    end
    assert_template("observations/namings/new")
    assert_select("div.alert-warning") do |elems|
      assert(elems.any? do |e|
               /MO does not recognize the name.*#{text_name}/ =~ e.to_s
             end,
             "Expected error about name not existing yet.")
    end

    open_form do |form|
      form.assert_value("naming_name", text_name)
      form.assert_unchecked("naming_reasons_1_check")
      form.assert_unchecked("naming_reasons_2_check")
      form.assert_unchecked("naming_reasons_3_check")
      form.assert_unchecked("naming_reasons_4_check")
      form.select(/vote/, /call it that/i)
      form.submit
    end
    assert_template("observations/show")
    assert_flash_text(/success/i)
    assert_objs_equal(obs, assigns(:observation))

    obs.reload
    name = Name.find_by(text_name: text_name)
    naming = Naming.last
    assert_names_equal(name, naming.name)
    assert_names_equal(name, obs.name)
    assert_equal("", name.author.to_s)

    # (Make sure naming shows up somewhere.)
    assert_match(text_name, response.body)
    # (Make sure there is an edit and destroy control for the new naming.)
    # (Now one: same for wide-screen as for mobile.)
    assert_select("a[href*='#{edit_naming_path(naming.id)}']", 1)
    assert_select("input.destroy_naming_link_#{naming.id}", 1)

    # Try changing it.
    author = "(Pers.) Grev."
    reason = "Test reason."
    click_mo_link(label: /edit/i, href: /#{edit_naming_path(naming.id)}/)
    assert_template("observations/namings/edit")
    open_form do |form|
      form.assert_value("naming_name", text_name)
      form.assert_checked("naming_reasons_1_check")
      form.uncheck("naming_reasons_1_check")
      form.change("naming_name", "#{text_name} #{author}")
      form.check("naming_reasons_2_check")
      form.change("naming_reasons_2_notes", reason)
      form.select("naming_vote_value", /call it that/i)
      form.submit
    end
    assert_template("observations/show")
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

    click_mo_link(label: /edit/i, href: /#{edit_naming_path(naming.id)}/)
    assert_template("observations/namings/edit")
    open_form do |form|
      form.assert_value("naming_name", "#{text_name} #{author}")
      form.assert_unchecked("naming_reasons_1_check")
      form.assert_value("naming_reasons_1_notes", "")
      form.assert_checked("naming_reasons_2_check")
      form.assert_value("naming_reasons_2_notes", reason)
      form.assert_unchecked("naming_reasons_3_check")
      form.assert_value("naming_reasons_3_notes", "")
    end
    click_mo_link(label: /cancel.*show/i)
    naming

    voter_session = open_session.extend(VoterDsl)
    voter_session.login!(rolf)
    assert_not_equal(namer_session.session[:session_id],
                     voter_session.session[:session_id])
    voter_session.vote_on_name(obs, naming)
    namer_session.failed_delete(obs)
    voter_session.change_mind(obs, naming)
    namer_session.successful_delete(obs, naming, text_name, orignal_name)
  end

  def test_sessions
    rolf_session = open_session.extend(NamerDsl)
    rolf_session.login!(rolf)
    mary_session = open_session.extend(VoterDsl)
    mary_session.login!(mary)
    assert_not_equal(mary_session.session[:session_id],
                     rolf_session.session[:session_id])
  end

  # Note that this only tests non-JS vote submission.
  # Most users will have their vote sent via AJAX from naming_vote_ajax.js
  def vote_on_name(obs, naming)
    get("/#{obs.id}")
    open_form("form#naming_vote_#{naming.id}") do |form|
      form.assert_value("vote_value", /no opinion/i)
      form.select("vote_value", /call it that/i)
      form.assert_value("vote_value", "3.0")
      form.submit("Cast Vote")
    end
    # assert_template("observations/show")
    assert_match(/call it that/i, response.body)
  end

  def change_mind(obs, naming)
    # "change_mind response.body".print_thing(response.body)
    get("/#{obs.id}")
    open_form("form#naming_vote_#{naming.id}") do |form|
      form.select("vote_value", /as if!/i)
      form.submit(:show_namings_cast.l)
    end
  end

  def create_name(obs, text_name); end

  def failed_delete(_obs)
    click_mo_link(label: /destroy/i, href: /namings/)
    assert_flash_text(/sorry/i)
  end

  def successful_delete(obs, naming, text_name, original_name)
    click_mo_link(label: /destroy/i, href: /#{naming_path(naming.id)}/)
    assert_template("observations/show")
    assert_objs_equal(obs, assigns(:observation))
    assert_flash_text(/success/i)

    obs.reload
    assert_names_equal(original_name, obs.name)
    assert_nil(Naming.safe_find(naming.id))
    assert_no_match(text_name, response.body)
  end
end
