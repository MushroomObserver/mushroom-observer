# frozen_string_literal: true

require("test_helper")

class CommentsIntegrationTest < CapybaraIntegrationTestCase
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
    login("katrina")
    visit("/#{obs.id}")

    # (Make sure there are no edit or destroy controls on existing comments.)
    assert_no_link(class: /edit_comment_/)
    assert_no_selector(class: /destroy_comment_/)

    click_link("Add Comment")
    assert_selector("body.comments__new")

    # (Make sure the form is for the correct object!)
    assert_selector("form[action*='/comments?target=#{obs.id}']")
    # (Make sure there is a tab to go back to observations/show.)
    assert_link(href: "/#{obs.id}")

    within("#comment_form") do
      click_commit # (submit without commenting anything)
    end
    assert_selector("body.comments__create")
    # (I don't care so long as it says something.)
    assert_flash_text(/\S/)

    within("#comment_form") do
      fill_in("comment_summary", with: summary)
      fill_in("comment_comment", with: message)
      click_commit
    end
    assert_selector("body.observations__show")
    assert_text("Observation #{obs.id}")

    com = Comment.last
    assert_equal(summary, com.summary)
    assert_equal(message, com.comment)

    # (Make sure comment shows up somewhere.)
    assert_text(summary)
    assert_text(message)
    # (Make sure there is an edit and destroy control for the new comment.)
    assert_link(class: /edit_comment_/)
    assert_selector(class: /destroy_comment_/)

    # Try changing it.
    click_link(href: /#{edit_comment_path(com.id)}/)
    assert_selector("body.comments__edit")
    within("#comment_form") do
      assert_field("comment_summary", with: summary)
      assert_field("comment_comment", with: message)
      fill_in("comment_comment", with: message2)
      click_commit
    end
    assert_selector("body.observations__show")
    assert_text("Observation #{obs.id}")

    com.reload
    assert_equal(summary, com.summary)
    assert_equal(message2, com.comment)

    # (Make sure comment shows up somewhere.)
    assert_text(summary)
    # Capybara assert_text strips textile markup
    assert_text(ActionController::Base.helpers.strip_tags(message2.t))
    # (There should be a link in there to look up Xylaria polymorpha.)
    assert_link(
      href: "#{MO.http_domain}/lookups/lookup_name/Xylaria+polymorpha"
    )

    # I grow weary of this comment.
    click_button(class: /destroy_comment_link_#{com.id}/)
    assert_selector("body.observations__show")
    assert_text("Observation #{obs.id}")
    assert_no_text(summary)
    assert_no_link(class: /edit_comment_/)
    assert_no_selector(class: /destroy_comment_/)
    assert_nil(Comment.safe_find(com.id))
  end
end
