# frozen_string_literal: true

require("test_helper")

module Views::Controllers::InatImports
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      @import = inat_imports(:rolf_inat_import)
    end

    def test_user_index_shows_import_row
      html = render_index(imports: InatImport.where(user: @user).to_a)

      assert_html(html, "td", text: @import.state.to_s)
    end

    def test_user_index_hides_user_column
      html = render_index(imports: InatImport.where(user: @user).to_a,
                          admin: false)

      assert_no_html(html, "th", text: :USER.t)
    end

    def test_admin_index_shows_user_column
      html = render_index(imports: InatImport.all.to_a, admin: true)

      assert_html(html, "th", text: :USER.t)
    end

    def test_results_link_shown_for_done_import_with_obs
      import = inat_imports(:lone_wolf_import)
      import.update!(imported_count: 3)

      html = render_index(imports: [import])

      path = routes.results_inat_import_path(import)
      assert_html(html, "a[href='#{path}']")
    end

    def test_results_link_hidden_when_imported_count_zero
      import = inat_imports(:lone_wolf_import)
      import.update!(imported_count: 0)

      html = render_index(imports: [import])

      path = routes.results_inat_import_path(import)
      assert_no_html(html, "a[href='#{path}']")
    end

    def test_results_link_hidden_for_non_done_import
      import = inat_imports(:katrina_inat_import)
      assert_not(import.Done?,
                 "Test needs an import fixture that is not Done")

      html = render_index(imports: [import])

      path = routes.results_inat_import_path(import)
      assert_no_html(html, "a[href='#{path}']")
    end

    private

    def render_index(imports:, admin: false)
      render(Index.new(imports: imports, admin: admin))
    end
  end
end
