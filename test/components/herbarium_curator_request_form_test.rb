# frozen_string_literal: true

require "test_helper"

class HerbariumCuratorRequestFormTest < ComponentTestCase
  def setup
    super
    @model = FormObject::HerbariumCuratorRequest.new
    @herbarium = herbaria(:nybg_herbarium)
    @html = render_form
  end

  def test_renders_herbarium_name
    assert_html(@html, "body", text: :HERBARIUM.l)
    assert_includes(@html, @herbarium.name)
  end

  def test_renders_notes_field
    assert_html(@html, "body", text: :NOTES.l)
    assert_html(@html,
                "textarea[name='herbarium_curator_request[notes]']" \
                "[rows='10']")
    assert_html(@html, "textarea[name='herbarium_curator_request[notes]']" \
                       "[data-autofocus]")
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
