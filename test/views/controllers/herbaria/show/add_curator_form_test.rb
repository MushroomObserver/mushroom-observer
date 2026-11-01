# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Herbaria
  class Show::AddCuratorFormTest < ComponentTestCase
    def test_renders_form_structure
      herbarium = herbaria(:nybg_herbarium)
      html = render(Show::AddCuratorForm.new(herbarium: herbarium))

      assert_html(html, "form#herbarium_curators_form[data-turbo='true']")
      assert_html(
        html,
        "form[action='#{routes.herbaria_curators_path(id: herbarium.id)}']"
      )
      assert_html(html, "input[name='herbarium_curator[login]'][type='text']")
      # The autocompleter's dropdown + hidden id field must actually
      # render (regression guard for the TextField#bare_input? bug --
      # label: false used to silently drop both).
      assert_html(html, "ul.virtual_list")
      assert_html(
        html, "input[name='herbarium_curator[login_id]'][type='hidden']"
      )
      assert_html(html, "button[type='submit']",
                  text: :show_herbarium_add_curator.t)
    end
  end
end
