# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Names::Lifeforms::Propagate
  class FormTest < ComponentTestCase
    def test_form_structure
      name = names(:coprinus_comatus)
      name.update!(lifeform: " lichen ") # Set a lifeform for testing
      html = render_form(name)

      # Form structure and action
      assert_html(html, "form#name_lifeform_propagate_form")
      assert_html(html, "form[action*='/names/#{name.id}/lifeforms/propagate']")
      assert_html(html, "button[type='submit']", text: :apply.ti)

      # Add section
      assert_includes(html, :add.ti)
      assert_includes(html, :propagate_lifeform_add.l)

      # Remove section
      assert_includes(html, :remove.ti)
      assert_includes(html, :propagate_lifeform_remove.l)

      # Tables for add and remove
      assert_equal(2, html.scan(/<table[^>]*class="[^"]*table-lifeform/).count)

      # Should have add checkbox for lifeform on name (lichen)
      assert_html(html, "input[type='checkbox'][name='propagate_lifeform" \
                        "[add_lichen]']")
    end

    private

    def render_form(name)
      model = FormObject::PropagateLifeform.new
      render(Form.new(model, name: name))
    end
  end
end
