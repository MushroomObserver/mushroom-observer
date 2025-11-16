# frozen_string_literal: true

require "test_helper"

class ImageVoteAnonymityFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_vote_counts
    form = render_form(num_anonymous: 5, num_public: 10)

    assert_includes(form, :image_vote_anonymity_num_anonymous.t)
    assert_includes(form, "5")
    assert_includes(form, :image_vote_anonymity_num_public.t)
    assert_includes(form, "10")
  end

  def test_renders_make_anonymous_button
    form = render_form(num_anonymous: 5, num_public: 10)

    assert_includes(form, :image_vote_anonymity_make_anonymous.l)
    assert_includes(form, 'type="submit"')
    assert_includes(form, "btn btn-default")
  end

  def test_renders_make_public_button
    form = render_form(num_anonymous: 5, num_public: 10)

    assert_includes(form, :image_vote_anonymity_make_public.l)
    assert_includes(form, 'type="submit"')
  end

  def test_form_has_correct_attributes
    form = render_form(num_anonymous: 5, num_public: 10)

    assert_includes(form, 'action="/test_action"')
    assert_includes(form, 'method="post"')
    assert_includes(form, 'name="_method"')
    assert_includes(form, 'value="patch"')
  end

  def test_anonymous_button_disabled_when_votes_exist
    form = render_form(num_anonymous: 5, num_public: 0)

    # Anonymous button should be disabled when there are anonymous votes
    button_value = Regexp.escape(:image_vote_anonymity_make_anonymous.l)
    assert_match(/<input[^>]*disabled[^>]*value="#{button_value}"/, form)
  end

  def test_public_button_disabled_when_votes_exist
    form = render_form(num_anonymous: 0, num_public: 10)

    # Public button should be disabled when there are public votes
    button_value = Regexp.escape(:image_vote_anonymity_make_public.l)
    assert_match(/<input[^>]*disabled[^>]*value="#{button_value}"/, form)
  end

  def test_both_buttons_enabled_when_no_votes
    form = render_form(num_anonymous: 0, num_public: 0)

    # Neither button should be disabled when there are no votes
    anon_value = Regexp.escape(:image_vote_anonymity_make_anonymous.l)
    pub_value = Regexp.escape(:image_vote_anonymity_make_public.l)
    assert_no_match(/<input[^>]*disabled[^>]*value="#{anon_value}"/, form)
    assert_no_match(/<input[^>]*disabled[^>]*value="#{pub_value}"/, form)
  end

  def test_both_buttons_disabled_when_both_have_votes
    form = render_form(num_anonymous: 5, num_public: 10)

    # Both buttons should be disabled when both have votes
    anon_value = Regexp.escape(:image_vote_anonymity_make_anonymous.l)
    pub_value = Regexp.escape(:image_vote_anonymity_make_public.l)
    assert_match(/<input[^>]*disabled[^>]*value="#{anon_value}"/, form)
    assert_match(/<input[^>]*disabled[^>]*value="#{pub_value}"/, form)
  end

  private

  def render_form(num_anonymous: 0, num_public: 0)
    form_object = FormObject::ImageVoteAnonymity.new(
      num_anonymous: num_anonymous,
      num_public: num_public
    )
    form = Components::ImageVoteAnonymityForm.new(
      form_object,
      action: "/test_action"
    )
    render(form)
  end
end
