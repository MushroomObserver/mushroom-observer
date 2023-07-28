# frozen_string_literal: true

require("test_helper")

class EmailsControllerTest < FunctionalTestCase
  def test_page_loads
    login
    get(:ask_webmaster_question)
    assert_template(:ask_webmaster_question)
    assert_form_action(action: :ask_webmaster_question)
  end

  def test_ask_questions
    # id = observations(:coprinus_comatus_obs).id
    # requires_login(:ask_observation_question, id: id)
    # assert_form_action(action: :ask_observation_question, id: id)

    id = mary.id
    requires_login(:ask_user_question, id: id)
    assert_form_action(action: :ask_user_question, id: id)

    id = images(:in_situ_image).id
    requires_login(:commercial_inquiry, id: id)
    assert_form_action(action: :commercial_inquiry, id: id)

    # Prove that trying to ask question of user who refuses questions
    # redirects to that user's page (instead of an email form).
    user = users(:no_general_questions_user)
    requires_login(:ask_user_question, id: user.id)
    assert_flash_text(:permission_denied.t)

    # Prove that it won't email someone who has opted out of all emails.
    mary.update(no_emails: true)
    requires_login(:ask_user_question, id: mary.id)
    assert_flash_text(:permission_denied.t)
  end

  def test_send_webmaster_question
    ask_webmaster_test("rolf@mushroomobserver.org",
                       response: :index)
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

  def test_send_webmaster_question_antispam_logged_in
    disable_unsafe_html_filter
    user = users(:rolf)
    login(user.login)
    ask_webmaster_test(user.email,
                       content: "https://",
                       response: :redirect,
                       flash: :runtime_delivered_message.t)
  end

  def test_anon_user_ask_webmaster_question
    get(:ask_webmaster_question)

    assert_response(:success)
    assert_head_title(:ask_webmaster_title.l)
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

  def test_send_commercial_inquiry
    image = images(:commercial_inquiry_image)
    params = {
      id: image.id,
      commercial_inquiry: {
        content: "Testing commercial_inquiry"
      }
    }
    post_requires_login(:commercial_inquiry, params)
    assert_redirected_to(image_path(image.id))
  end

  # def test_send_ask_observation_question
  #   obs = observations(:minimal_unknown_obs)
  #   params = {
  #     id: obs.id,
  #     question: {
  #       content: "Testing question"
  #     }
  #   }
  #   post_requires_login(:ask_observation_question, params)
  #   assert_redirected_to(observation_path(obs.id))
  #   assert_flash_text(:runtime_ask_observation_question_success.t)
  # end

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
    assert_redirected_to(user_path(user.id))
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

    get(:merge_request, params: params)
    assert_response(:redirect)

    login("rolf")
    get(:merge_request, params: params.except(:type))
    assert_response(:redirect)
    get(:merge_request, params: params.except(:old_id))
    assert_response(:redirect)
    get(:merge_request, params: params.except(:new_id))
    assert_response(:redirect)
    get(:merge_request, params: params.merge(type: :Bogus))
    assert_response(:redirect)
    get(:merge_request, params: params.merge(old_id: -123))
    assert_response(:redirect)
    get(:merge_request, params: params.merge(new_id: -456))
    assert_response(:redirect)

    get(:merge_request, params: params)
    assert_response(:success)
    assert_names_equal(name1, assigns(:old_obj))
    assert_names_equal(name2, assigns(:new_obj))
    url = "merge_request?new_id=#{name2.id}&old_id=#{name1.id}&type=Name"
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

    post(:merge_request, params: params)
    assert_response(:redirect)
    assert_equal(email_count, ActionMailer::Base.deliveries.count)

    login("rolf")
    post(:merge_request, params: params)
    assert_response(:redirect)
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    assert_match(/SHAZAM/, ActionMailer::Base.deliveries.last.to_s)
  end

  def test_email_name_change_request_get
    name = names(:lactarius)
    assert(name.icn_id, "Test needs a fixture with an icn_id")
    assert(name.dependents?, "Test needs a fixture with dependents")
    params = {
      name_id: name.id,
      new_name_with_icn_id: "#{name.search_name} [#777]"
    }
    login("mary")

    get(:name_change_request, params: params)
    assert_select(
      "#title", text: :email_name_change_request_title.l, count: 1
    )
  end

  def test_email_name_change_request_post
    name = names(:lactarius)
    assert(name.icn_id, "Test needs a fixture with an icn_id")
    assert(name.dependents?, "Test needs a fixture with dependents")
    params = {
      name_id: name.id,
      new_name_with_icn_id: "#{name.search_name} [#777]"
    }
    login("mary")

    post(:name_change_request, params: params)
    assert_redirected_to(
      name_path(id: name.id),
      "Sending Name Change Request should redirect to Name page"
    )
  end
end
