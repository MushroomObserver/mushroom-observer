# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Herbaria::CuratorRequests
  class FormTest < ComponentTestCase
    def setup
      super
      @model = FormObject::HerbariumCuratorRequest.new
      @herbarium = herbaria(:nybg_herbarium)
      @html = render_form
    end

    def test_renders_herbarium_name
      assert_html(@html, ".form-group", text: "#{:HERBARIUM.l}:")
      assert_includes(@html, @herbarium.name)
    end

    def test_renders_notes_field
      assert_html(@html, "label[for='herbarium_curator_request_notes']",
                  text: :NOTES.l)
      assert_html(@html,
                  "textarea[name='herbarium_curator_request[notes]']" \
                  "[rows='10'][data-autofocus]")
    end

    def test_renders_submit_button
      assert_html(@html, "button[type='submit']", text: :SEND.l)
      assert_html(@html, "button[type='submit'][data-turbo-submits-with]")
    end

    private

    def render_form
      render(Form.new(@model, herbarium: @herbarium))
    end
  end
end
