require "test_helper"

class EmailControllerTest < FunctionalTestCase

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

  def test_send_webmaster_question
    ask_webmaster_test("rolf@mushroomobserver.org",
                       response: { controller: :rss_logs,
                                   action: :index })
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

  def test_email_features
    page = :email_features
    params = { feature_email: { content: "test" } }

    logout
    post(page, params: params)
    assert_redirected_to(controller: :account, action: :login)

    login("rolf")
    post(page, params: params)
    assert_redirected_to(controller: :rss_logs, action: :index)
    assert_flash_text(/denied|only.*admin/i)

    make_admin("rolf")
    post_with_dump(page, params)
    assert_redirected_to(controller: :users, action: :users_by_name)
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
    assert_redirected_to(controller: :images, action: :show, id: image.id)
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
    assert_redirected_to(controller: :observations, action: :show)
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
    assert_redirected_to(controller: :users, action: :show, id: user.id)
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

end
