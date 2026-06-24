# frozen_string_literal: true

require("test_helper")

module Views::Controllers::FieldSlips
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      controller.define_singleton_method(:active_project_tab) { "field_slips" }
    end

    # When the project has a `field_slip_prefix` and the current user
    # is a member, the "Create field slip" button renders as a GET
    # link to `new_project_field_slip_path`.
    def test_create_button_renders_for_project_member
      project = projects(:eol_project) # prefix: EOL; rolf is a member
      html = render_index(project: project)

      expected = routes.new_project_field_slip_path(project_id: project.id)
      assert_html(html, "a[href='#{expected}']")
    end

    def test_no_create_button_when_no_prefix
      projects(:bolete_project)
      # bolete_project has prefix BLT but rolf is not a member —
      # use a project without a prefix to hit the non-member branch.
      # `lone_wolf_project` has only lone_wolf as member.
      project = projects(:lone_wolf_project)
      html = render_index(project: project)

      # No prefix set → nudge renders only for admins, no create button
      assert_no_html(html, "a[href*='new_project_field_slip']")
    end

    private

    def render_index(project: nil)
      render(Index.new(
               objects: [],
               query: Query.lookup_and_save(:FieldSlip),
               project: project,
               pagination_data: PaginationData.new
             ))
    end
  end
end
