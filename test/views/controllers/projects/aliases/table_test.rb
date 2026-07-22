# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Aliases
  class TableTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @project = projects(:eol_project)
    end

    def test_renders_index_table_with_alias_rows
      html = render_table

      assert_html(html, "table##{Table::TABLE_ID}")
      assert_html(html, "table.table-project-members")

      # Column headers
      assert_includes(html, :name.ti)
      assert_includes(html, :target_type.ti)
      assert_includes(html, :target.ti)
      assert_includes(html, :actions.ti)

      # Linked target cells (User-target row + Location-target row)
      assert_html(html, "td a[href='/users/#{@user.id}']")
      assert_html(
        html,
        "td a[href='/locations/#{project_aliases(:two).target_id}']"
      )

      # Edit and destroy action buttons per row
      assert_html(html,
                  "a[href*='/projects/#{@project.id}/aliases/" \
                  "#{project_aliases(:one).id}/edit']")
      assert_html(html,
                  "form[action*='/projects/#{@project.id}/aliases/" \
                  "#{project_aliases(:one).id}']")
    end

    def test_empty_alias_list_renders_just_headers
      html = render_table(project_aliases: ProjectAlias.none)

      assert_html(html, "table##{Table::TABLE_ID}")
      assert_html(html, "th", text: :name.ti)
      # No body rows
      assert_no_html(html, "tbody tr")
    end

    private

    def render_table(project_aliases: @project.aliases)
      render(Table.new(project_aliases: project_aliases))
    end
  end
end
