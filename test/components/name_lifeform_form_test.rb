# frozen_string_literal: true

require "test_helper"

class NameLifeformFormTest < ComponentTestCase
  def test_form_structure
    name = names(:coprinus_comatus)
    html = render_form(name)

    # Form structure and action
    assert_html(html, "form#name_lifeform_form")
    assert_html(html, "form[action*='/names/#{name.id}/lifeform']")
    assert_html(html, "input[type='submit'][value='#{:SAVE.t}']")

    # Help text
    assert_includes(html, :edit_lifeform_help.t)

    # Table with lifeform checkboxes
    assert_html(html, "table.table-lifeform")
    Name.all_lifeforms.each do |word|
      assert_html(html, "input[type='checkbox'][name='lifeform[#{word}]']")
      assert_includes(html, :"lifeform_#{word}".l)
    end
  end

  private

  def render_form(name)
    model = FormObject::Lifeform.from_name(name)
    render(Components::NameLifeformForm.new(model, name: name))
  end
end
