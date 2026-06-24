# frozen_string_literal: true

require("test_helper")

module Views::Controllers::VisualGroups
  class FormTest < ComponentTestCase
    def setup
      super
      @visual_model = visual_models(:visual_model_one)
      @visual_group = VisualGroup.new(visual_model: @visual_model)
      @html = render_form
    end

    def test_renders_form_with_name_field
      assert_html(@html, "input[name='visual_group[name]'][size='40']")
      assert_html(@html, "span", text: :VISUAL_GROUP.l)
    end

    def test_renders_form_with_description_field
      assert_html(@html, "label[for='visual_group_description']",
                  text: :DESCRIPTION.l)
      assert_html(@html,
                  "textarea[name='visual_group[description]']" \
                  "[rows='10'][cols='60']")
    end

    def test_renders_form_with_approved_checkbox
      assert_html(@html, "label[for='visual_group_approved']",
                  text: :APPROVED.l)
      assert_html(@html, "input[name='visual_group[approved]']")
    end

    def test_renders_submit_button
      assert_html(@html, "button[type='submit']", text: :SUBMIT.t)
      assert_html(@html, ".center-block")
    end

    def test_auto_determines_url_for_new_visual_group
      html = render_form_without_action
      expected_action = "/visual_models/#{@visual_model.id}/visual_groups"
      assert_html(html, "form[action='#{expected_action}']")
    end

    def test_auto_determines_url_for_existing_visual_group
      @visual_group = visual_groups(:visual_group_one)
      html = render_form_without_action

      assert_html(html,
                  "form[action='/visual_groups/#{@visual_group.id}']")
    end

    def test_renders_errors_when_model_has_errors
      @visual_group.errors.add(:name, "can't be blank")
      html = render_form

      assert_html(html, "#error_explanation")
      assert_html(html, "h2")
      assert_html(html, "li")
      error_text = Nokogiri::HTML(html).at_css("#error_explanation").text
      assert_includes(error_text, "1 #{:error.t}")
      assert_match(/Name can.{1,6}t be blank/, error_text)
    end

    private

    def render_form
      render(Form.new(@visual_group,
                      visual_model: @visual_model,
                      action: "/test_action",
                      id: "visual_group_form"))
    end

    def render_form_without_action
      render(Form.new(@visual_group, visual_model: @visual_model))
    end
  end
end
