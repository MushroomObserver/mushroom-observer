# frozen_string_literal: true

require "test_helper"

class HerbariumCuratorRequestFormTest < UnitTestCase
  include ComponentTestHelper

  # Test model that includes necessary ActiveModel modules
  class TestRequest
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :notes, :string

    def persisted?
      false
    end
  end

  def setup
    @model = TestRequest.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_herbarium_name
    form = render_form

    assert_includes(form, :HERBARIUM.l)
    assert_includes(form, "Test Herbarium")
  end

  def test_renders_notes_field
    form = render_form

    assert_includes(form, :NOTES.l)
    assert_includes(form, "rows=\"10\"")
    assert_includes(form, "data-autofocus")
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SEND.l)
    assert_includes(form, "btn btn-default")
    assert_includes(form, "center-block my-3")
    assert_includes(form, "data-turbo-submits-with")
  end

  private

  def render_form
    form = Components::HerbariumCuratorRequestForm.new(
      @model,
      herbarium_name: "Test Herbarium",
      action: "/test_action",
      id: "herbarium_curator_request_form"
    )
    render(form)
  end
end
