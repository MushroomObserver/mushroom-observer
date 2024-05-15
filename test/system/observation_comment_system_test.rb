# frozen_string_literal: true

require("application_system_test_case")

class ObservationCommentSystemTest < ApplicationSystemTestCase
  # Katrina makes a comment on Rolf's observation.
  # Rolf should get the comment immediately via websocket.
  # Katrina edits the comment, rolf should get the change immediately.
  # Katrina deletes the comment, rolf should get the deletion immediately.
  def test_add_and_edit_comment
    rolf = users("rolf")
    katrina = users("katrina")
    obs = observations(:coprinus_comatus_obs)
    # This is rolf's obs, and there are no comments yet on it.

    # Rolf logs in and goes to his obs.
    using_session("rolf_session") do
      login!(rolf)
      assert_link("Your Observations")
      click_on("Your Observations")
      # obs = observations(:peltigera_obs)

      assert_selector("body.observations__index")
      assert_link(text: /#{obs.text_name}/)
      click_link(text: /#{obs.text_name}/)

      assert_selector("body.observations__show")
      assert_selector("#comments_for_object")
      assert_selector("turbo-cable-stream-source[connected]")
      within("#comments_for_object") do
        assert_no_link(class: /edit_comment_/)
        assert_no_selector(class: /destroy_comment_/)
        assert_link(:show_comments_add_comment.l)
      end
    end

    # browser = page.driver.browser
    using_session("katrina_session") do
      login!(katrina)
      visit("/#{obs.id}")

      assert_selector("body.observations__show")
      assert_selector("#comments_for_object")
      assert_selector("turbo-cable-stream-source[connected]")
      within("#comments_for_object") do
        assert_no_link(class: /edit_comment_/)
        assert_no_selector(class: /destroy_comment_/)
        assert_link(:show_comments_add_comment.l)
        find(:css, ".new_comment_link_#{obs.id}").trigger("click")
      end

      assert_selector("#modal_comment")
      within("#modal_comment") do
        assert_selector("#comment_comment")
        fill_in("comment_comment", with: "What do you mean, Coprinus?")
        click_commit
      end
      # Cannot submit comment without a summary
      assert_selector("#modal_comment_flash", text: /Missing/)
      within("#modal_comment") do
        assert_selector("#comment_comment", text: "What do you mean, Coprinus?")
        fill_in("comment_summary", with: "A load of bollocks")
        click_commit
      end
      assert_no_selector("#modal_comment")
    end

    # Define `com` outside session context so it can be used in any session
    com = Comment.last

    using_session("katrina_session") do
      scroll_to(find("#comments_for_object"), align: :center)
      within("#comment_#{com.id}") do
        assert_text("A load of bollocks")
        assert_selector(".show_user_link_#{katrina.id}")
        assert_selector(".edit_comment_link_#{com.id}")
        assert_selector(".destroy_comment_link_#{com.id}")
      end
    end

    using_session("rolf_session") do
      scroll_to(find("#comments_for_object"), align: :center)
      within("#comment_#{com.id}") do
        assert_text("A load of bollocks")
        assert_selector(".show_user_link_#{katrina.id}")
        assert_no_selector(".edit_comment_link_#{com.id}")
        assert_no_selector(".destroy_comment_link_#{com.id}")
      end
    end

    using_session("katrina_session") do
      scroll_to(find("#comments_for_object"), align: :center)
      within("#comments_for_object") do
        find(:css, ".edit_comment_link_#{com.id}").trigger("click")
      end

      assert_selector("#modal_comment_#{com.id}")
      within("#modal_comment_#{com.id}") do
        fill_in("comment_summary", with: "Exciting discovery")
        fill_in(
          "comment_comment",
          with: "What I meant was, this could be _Xylaria polymorpha_, no?"
        )
        click_commit
      end
      assert_no_selector("#modal_comment_#{com.id}")

      within("#comment_#{com.id}") do
        assert_no_text("A load of bollocks")
        assert_text("Exciting discovery")
        assert_link(
          href: MO.http_domain + lookup_name_path("Xylaria+polymorpha")
        )
        assert_selector(".destroy_comment_link_#{com.id}")
      end
    end

    using_session("rolf_session") do
      scroll_to(find("#comments_for_object"), align: :center)
      within("#comment_#{com.id}") do
        assert_no_text("A load of bollocks")
        assert_text("Exciting discovery")
        assert_selector(".show_user_link_#{katrina.id}")
        assert_no_selector(".edit_comment_link_#{com.id}")
        assert_no_selector(".destroy_comment_link_#{com.id}")
      end
    end

    using_session("katrina_session") do
      scroll_to(find("#comments_for_object"), align: :center)
      within("#comment_#{com.id}") do
        assert_no_text("A load of bollocks")
        assert_text("Exciting discovery")
        assert_selector(".destroy_comment_link_#{com.id}")
        accept_confirm do
          find(:css, ".destroy_comment_link_#{com.id}").trigger("click")
        end
      end
      within("#comments_for_object") do
        assert_no_text("Exciting discovery")
        assert_no_selector(".destroy_comment_link_#{com.id}")
      end
    end

    using_session("rolf_session") do
      scroll_to(find("#comments_for_object"), align: :center)
      within("#comments_for_object") do
        assert_no_text("Exciting discovery")
        assert_no_selector(".destroy_comment_link_#{com.id}")
      end
    end
  end
end
