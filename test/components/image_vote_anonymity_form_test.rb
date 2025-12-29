# frozen_string_literal: true

require "test_helper"

class ImageVoteAnonymityFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_vote_counts
    html = render_form(num_anonymous: 5, num_public: 10)

    assert_html(html, "body", text: :image_vote_anonymity_num_anonymous.l)
    assert_includes(html, "5")
    assert_html(html, "body", text: :image_vote_anonymity_num_public.l)
    assert_includes(html, "10")
  end

  def test_renders_make_public_button
    html = render_form(num_anonymous: 5, num_public: 10)

    assert_html(
      html,
      "input[type='submit'][value='#{:image_vote_anonymity_make_public.l}']"
    )
  end

  def test_form_has_correct_attributes
    html = render_form(num_anonymous: 5, num_public: 10)

    assert_html(html, "form[action='/images/votes/anonymity']")
    assert_html(html, "form[method='post']")
    assert_html(html, "input[name='_method'][value='put']")
  end

  def test_public_button_disabled_when_no_anon_votes_exist
    html = render_form(num_anonymous: 0, num_public: 10)

    # Public button should be disabled when there are no anonymous votes
    button_value = Regexp.escape(:image_vote_anonymity_make_public.l)
    assert_match(/<input[^>]*disabled[^>]*value="#{button_value}"/, html)
  end

  private

  def render_form(num_anonymous: 0, num_public: 0)
    form_object = FormObject::ImageVoteAnonymity.new(
      num_anonymous: num_anonymous,
      num_public: num_public
    )
    render(Components::ImageVoteAnonymityForm.new(form_object))
  end
end
