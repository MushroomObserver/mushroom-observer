# frozen_string_literal: true

require("application_system_test_case")

class WebmasterQuestionSystemTest < ApplicationSystemTestCase
  def test_report_a_bug_link_from_sidebar
    rolf = users("rolf")
    login!(rolf)

    # Visit a page that has the info sidebar (e.g., homepage or info page)
    visit("/")

    # Find and click the "Report a bug" link in the sidebar
    within("#sidebar") do
      assert_link(:app_report_a_bug.t)
      click_link(:app_report_a_bug.t)
    end

    # Should be on the webmaster question form page
    assert_text("Email Question or Comment")
    assert_field(:ask_webmaster_your_email.t, with: rolf.email)
    assert_field(:ask_webmaster_question.t)
  end

  def test_send_webmaster_question_as_logged_in_user
    rolf = users("rolf")
    login!(rolf)

    # Record the current email count
    email_count = ActionMailer::Base.deliveries.count

    # Visit the webmaster question form directly
    visit(new_admin_emails_webmaster_questions_path)

    assert_text("Email Question or Comment")

    # Email field should be pre-filled with user's email
    assert_field(:ask_webmaster_your_email.t, with: rolf.email)

    # Fill in the question
    fill_in(:ask_webmaster_question.t, with: "I found a bug in the observation form")

    # Submit the form
    click_commit

    # Should redirect to homepage with success message
    assert_current_path("/")
    assert_text(:runtime_ask_webmaster_success.t)

    # Verify email was sent
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    email = ActionMailer::Base.deliveries.last
    assert_match(/#{rolf.email}/, email.to_s)
    assert_match(/bug in the observation form/, email.to_s)
  end

  def test_send_webmaster_question_as_anonymous_user
    # Record the current email count
    email_count = ActionMailer::Base.deliveries.count

    # Visit the webmaster question form without logging in
    visit(new_admin_emails_webmaster_questions_path)

    assert_text("Email Question or Comment")

    # Email field should be empty
    assert_field(:ask_webmaster_your_email.t, with: "")

    # Fill in both email and question
    fill_in(:ask_webmaster_your_email.t, with: "concerned_user@example.com")
    fill_in(:ask_webmaster_question.t,
            with: "I noticed something odd with the species page")

    # Submit the form
    click_commit

    # Should redirect to homepage with success message
    assert_current_path("/")
    assert_text(:runtime_ask_webmaster_success.t)

    # Verify email was sent
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    email = ActionMailer::Base.deliveries.last
    assert_match(/concerned_user@example.com/, email.to_s)
    assert_match(/odd with the species page/, email.to_s)
  end

  def test_webmaster_question_validation_missing_email
    visit(new_admin_emails_webmaster_questions_path)

    # Leave email blank
    fill_in(:ask_webmaster_your_email.t, with: "")
    fill_in(:ask_webmaster_question.t, with: "This is my question")

    click_commit

    # Should show error message
    assert_text(:runtime_ask_webmaster_need_address.t)
  end

  def test_webmaster_question_validation_missing_content
    visit(new_admin_emails_webmaster_questions_path)

    fill_in(:ask_webmaster_your_email.t, with: "test@example.com")
    fill_in(:ask_webmaster_question.t, with: "")

    click_commit

    # Should show error message
    assert_text(:runtime_ask_webmaster_need_content.t)
  end

  def test_webmaster_question_spam_protection_for_anonymous_users
    visit(new_admin_emails_webmaster_questions_path)

    fill_in(:ask_webmaster_your_email.t, with: "spammer@example.com")
    # Content with URL should trigger spam protection
    fill_in(:ask_webmaster_question.t, with: "Check out http://spam-site.com")

    click_commit

    # Should show antispam error
    assert_text(:runtime_ask_webmaster_antispam.t)
  end

  def test_webmaster_question_allows_urls_for_logged_in_users
    rolf = users("rolf")
    login!(rolf)

    email_count = ActionMailer::Base.deliveries.count

    visit(new_admin_emails_webmaster_questions_path)

    # Logged in users can include URLs in their questions
    fill_in(:ask_webmaster_question.t,
            with: "The page at https://mushroomobserver.org/123 has an error")

    click_commit

    # Should succeed for logged-in users
    assert_current_path("/")
    assert_text(:runtime_ask_webmaster_success.t)

    # Verify email was sent
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
  end
end
