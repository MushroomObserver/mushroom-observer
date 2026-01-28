# frozen_string_literal: true

require("test_helper")

class WebmasterQuestionIntegrationTest < CapybaraIntegrationTestCase
  include ActiveJob::TestHelper

  def test_logged_in_user_submits_webmaster_question
    rolf = users(:rolf)
    login!(rolf)

    email_count = ActionMailer::Base.deliveries.count

    # Visit the webmaster question form
    visit(new_admin_emails_webmaster_questions_path)

    perform_enqueued_jobs do
      within("#webmaster_question_form") do
        # Email field should be pre-filled with user's email
        assert_field("email_email", with: rolf.email)

        # Fill in the question
        fill_in("email_message",
                with: "I found a bug in the observation form")

        # Submit the form
        click_commit
      end

      # Should redirect with success message
      assert_flash_text(:runtime_ask_webmaster_success.l)
    end

    # Verify email was sent
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    email = ActionMailer::Base.deliveries.last
    assert_match(/#{rolf.email}/, email.to_s)
    assert_match(/bug in the observation form/, email.to_s)
  end

  def test_anonymous_user_submits_webmaster_question
    email_count = ActionMailer::Base.deliveries.count

    # Visit the webmaster question form without logging in
    visit(new_admin_emails_webmaster_questions_path)

    perform_enqueued_jobs do
      within("#webmaster_question_form") do
        # Fill in both email and question
        fill_in("email_email",
                with: "concerned_user@example.com")
        fill_in("email_message",
                with: "I noticed something odd with the species page")

        # Submit the form
        click_commit
      end

      # Should redirect with success message
      assert_flash_text(:runtime_ask_webmaster_success.l)
    end

    # Verify email was sent
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    email = ActionMailer::Base.deliveries.last
    assert_match(/concerned_user@example.com/, email.to_s)
    assert_match(/odd with the species page/, email.to_s)
  end

  def test_validation_error_missing_email
    visit(new_admin_emails_webmaster_questions_path)

    within("#webmaster_question_form") do
      # Leave email blank
      fill_in("email_email", with: "")
      fill_in("email_message",
              with: "This is my question")

      click_commit
    end

    # Should show error message
    assert_flash_text(:runtime_ask_webmaster_need_address.l)
  end

  def test_validation_error_missing_content
    visit(new_admin_emails_webmaster_questions_path)

    within("#webmaster_question_form") do
      fill_in("email_email", with: "test@example.com")
      fill_in("email_message", with: "")

      click_commit
    end

    # Should show error message
    assert_flash_text(:runtime_ask_webmaster_need_content.l)
  end

  def test_spam_protection_for_anonymous_users
    visit(new_admin_emails_webmaster_questions_path)

    within("#webmaster_question_form") do
      fill_in("email_email", with: "spammer@example.com")
      # Content with URL should trigger spam protection
      fill_in("email_message",
              with: "Check out http://spam-site.com")

      click_commit
    end

    # Should show antispam error
    assert_flash_text(/robot spam/)
  end

  def test_logged_in_users_can_include_urls
    rolf = users(:rolf)
    login!(rolf)

    email_count = ActionMailer::Base.deliveries.count

    visit(new_admin_emails_webmaster_questions_path)

    perform_enqueued_jobs do
      within("#webmaster_question_form") do
        # Logged in users can include URLs in their questions
        fill_in("email_message",
                with: "Page https://mushroomobserver.org/123 has an error")

        click_commit
      end

      # Should succeed for logged-in users
      assert_flash_text(:runtime_ask_webmaster_success.l)
    end

    # Verify email was sent
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
  end
end
