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
    super
    @model = TestRequest.new
    @herbarium = herbaria(:nybg_herbarium)
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_herbarium_name
    assert_html(@html, "body", text: :HERBARIUM.l)
    assert_includes(@html, @herbarium.name)
  end

  def test_renders_notes_field
    assert_html(@html, "body", text: :NOTES.l)
    assert_html(@html, "textarea[rows='10']")
    assert_html(@html, "textarea[data-autofocus]")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".btn.btn-default")
    assert_html(@html, ".center-block.my-3")
    assert_html(@html, "input[data-turbo-submits-with]")
  end

  private

  def render_form
    form = Components::HerbariumCuratorRequestForm.new(
      @model,
      herbarium: @herbarium
    )
    render(form)
  end
end
