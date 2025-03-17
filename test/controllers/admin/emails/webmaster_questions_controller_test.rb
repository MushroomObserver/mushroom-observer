# frozen_string_literal: true

require("test_helper")

module Admin
  module Emails
    class WebmasterQuestionsControllerTest < FunctionalTestCase
      def test_page_loads
        login
        get(:new)
        assert_template("admin/emails/webmaster_questions/new")
        assert_form_action(action: :create)
      end

      def test_send_webmaster_question
        ask_webmaster_test("rolf@mushroomobserver.org", response: :index)
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
        get(:new)

        assert_response(:success)
        assert_head_title(:ask_webmaster_title.l)
      end

      def ask_webmaster_test(email, args)
        response = args[:response] || :success
        flash = args[:flash]
        post(:create,
             params: {
               user: { email: email },
               question: { content: args[:content] || "Some content" }
             })
        assert_response(response)
        assert_flash_text(flash) if flash
      end
    end
  end
end
