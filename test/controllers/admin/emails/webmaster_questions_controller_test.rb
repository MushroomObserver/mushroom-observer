# frozen_string_literal: true

require("test_helper")

module Admin
  module Emails
    class WebmasterQuestionsControllerTest < FunctionalTestCase
      include ActiveJob::TestHelper

      def test_page_loads
        login
        get(:new)
        assert_template("admin/emails/webmaster_questions/new")
        assert_form_action(action: :create)
      end

      def test_page_loads_turbo_stream
        login
        get(:new, format: :turbo_stream)
        assert_response(:success)
      end

      def test_send_webmaster_question
        email_count = ActionMailer::Base.deliveries.count
        login("rolf")
        perform_enqueued_jobs do
          ask_webmaster_test(
            "rolf@mushroomobserver.org",
            response: :redirect,
            flash: :runtime_ask_webmaster_success.t
          )
        end
        assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
        assert_match(/rolf@mushroomobserver.org/,
                     ActionMailer::Base.deliveries.last.to_s)
      end

      def test_send_webmaster_question_anonymous
        email_count = ActionMailer::Base.deliveries.count
        perform_enqueued_jobs do
          ask_webmaster_test(
            "anonymous@example.com",
            message: "I noticed something odd",
            response: :redirect,
            flash: :runtime_ask_webmaster_success.t
          )
        end
        assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
        assert_match(/anonymous@example.com/,
                     ActionMailer::Base.deliveries.last.to_s)
      end

      def test_send_webmaster_question_need_address
        ask_webmaster_test("", flash: :runtime_ask_webmaster_need_address.t)
      end

      def test_send_webmaster_question_spammer
        ask_webmaster_test(
          "spammer",
          flash: :runtime_ask_webmaster_need_address.t
        )
      end

      def test_send_webmaster_question_need_content
        ask_webmaster_test("bogus@email.com",
                           message: "",
                           flash: :runtime_ask_webmaster_need_content.t)
      end

      def test_send_webmaster_question_antispam
        disable_unsafe_html_filter
        ask_webmaster_test("bogus@email.com",
                           message: "Buy <a href='http://junk'>Me!</a>",
                           flash: :runtime_ask_webmaster_antispam.t)
        ask_webmaster_test("okay_user@email.com",
                           message: "iwxobjUzvkhmaCt",
                           flash: :runtime_ask_webmaster_antispam.t)
      end

      def test_send_webmaster_question_antispam_logged_in
        disable_unsafe_html_filter
        email_count = ActionMailer::Base.deliveries.count
        user = users(:rolf)
        login(user.login)
        perform_enqueued_jobs do
          ask_webmaster_test(
            user.email,
            message: "https://mushroomobserver.org/123 has an error",
            response: :redirect,
            flash: :runtime_ask_webmaster_success.t
          )
        end
        assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
      end

      def test_anon_user_ask_webmaster_question
        get(:new)

        assert_response(:success)
        assert_head_title(:ask_webmaster_title.l)
      end

      def ask_webmaster_test(email, args)
        response = args[:response] || :success
        flash = args[:flash]
        post(:create,
             params: {
               webmaster_question: {
                 email: email,
                 message: args[:message] || "Some message"
               }
             })
        assert_response(response)
        assert_flash_text(flash) if flash
      end
    end
  end
end
