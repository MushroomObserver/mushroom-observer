# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Herbaria
  class Show::CuratorTableTest < ComponentTestCase
    def setup
      super
      @herb = herbaria(:nybg_herbarium) # curators: rolf, roy
    end

    # A curator of the herbarium sees delete buttons for all curators.
    def test_renders_delete_buttons_for_curator
      controller.instance_variable_set(:@user, users(:rolf))
      html = render_curator_table

      roy = users(:roy)
      curator_path = routes.herbaria_curator_path(@herb, user: roy.id)
      assert_html(html,
                  "form[action='#{curator_path}'] " \
                  "button[id='delete_herbarium_curator_link_#{roy.id}']")
      assert_html(html, "input[name='_method'][value='delete']")
    end

    # A non-curator sees no delete buttons.
    def test_no_delete_button_for_non_curator
      controller.instance_variable_set(:@user, users(:mary))
      html = render_curator_table

      assert_no_html(html, "button[id*='delete_herbarium_curator_link']")
    end

    private

    def render_curator_table
      render(Show::CuratorTable.new(herbarium: @herb))
    end
  end
end
