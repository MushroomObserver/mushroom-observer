# frozen_string_literal: true

require "test_helper"

class ImageVoteAnonymityFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_vote_counts
    form = render_form

    assert_includes(form, :image_vote_anonymity_num_anonymous.t)
    assert_includes(form, "5")
    assert_includes(form, :image_vote_anonymity_num_public.t)
    assert_includes(form, "10")
  end

  def test_renders_make_anonymous_button
    form = render_form

    assert_includes(form, :image_vote_anonymity_make_anonymous.l)
    assert_includes(form, 'type="submit"')
    assert_includes(form, "btn btn-default")
  end

  def test_renders_make_public_button
    form = render_form

    assert_includes(form, :image_vote_anonymity_make_public.l)
    assert_includes(form, 'type="submit"')
  end

  def test_form_has_correct_attributes
    form = render_form

    assert_includes(form, 'action="/test_action"')
    assert_includes(form, 'method="post"')
    assert_includes(form, 'name="_method"')
    assert_includes(form, 'value="patch"')
  end

  private

  def render_form
    form_object = FormObject::ImageVoteAnonymity.new(
      num_anonymous: 5,
      num_public: 10
    )
    form = Components::ImageVoteAnonymityForm.new(
      form_object,
      action: "/test_action"
    )
    render(form)
  end
end
