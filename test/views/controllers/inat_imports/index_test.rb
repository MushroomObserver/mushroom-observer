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

    def test_results_link_shown_when_import_has_results
      import = inat_imports(:lone_wolf_import)

      html = render_index(imports: [import], result_import_ids: [import.id])

      path = routes.results_inat_import_path(import)
      assert_html(html, "a[href='#{path}']")
    end

    def test_results_link_hidden_when_import_has_no_results
      import = inat_imports(:lone_wolf_import)

      html = render_index(imports: [import])

      path = routes.results_inat_import_path(import)
      assert_no_html(html, "a[href='#{path}']")
    end

    def test_context_nav_includes_new_link
      html = render_index(imports: InatImport.where(user: @user).to_a)

      assert_html(html, "a[href='#{routes.new_inat_import_path}']")
    end

    def test_when_column_is_first_and_shows_updated_at
      @import.update_column(:updated_at, Time.zone.parse("2026-01-02 03:04:05"))

      html = render_index(imports: [@import])

      assert_html(html, "th:first-child", text: :inat_imports_index_when_utc.l)
      assert_html(html, "td",
                  text: @import.updated_at.utc.strftime("%Y-%m-%d %H:%M:%S"))
    end

    def test_report_column_links_to_show_page
      html = render_index(imports: [@import])

      assert_html(html, "th", text: :REPORTS.l)
      assert_html(html, "a[href='#{routes.inat_import_path(@import)}']",
                  text: :REPORT.l)
    end

    private

    def render_index(imports:, admin: false, result_import_ids: [])
      render(Index.new(imports: imports, admin: admin,
                       result_import_ids: result_import_ids))
    end
  end
end
