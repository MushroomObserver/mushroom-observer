# frozen_string_literal: true

require("test_helper")

module Projects
  class ObsFooterTest < ComponentTestCase
    def test_renders_add_and_exclude_buttons_by_default
      html = render_footer(show_excluded: false)

      assert_html(html, "#update_footer_#{obs.id}")
      assert_includes(html, :ADD.l)
      assert_includes(html, :EXCLUDE.l)
      assert_html(html, "form[action*='add_observation']")
      assert_html(html, "form[action*='exclude_observation']")
    end

    def test_renders_only_add_button_when_showing_excluded
      html = render_footer(show_excluded: true)

      assert_html(html, "#update_footer_#{obs.id}")
      assert_includes(html, :ADD.l)
      assert_html(html, "form[action*='add_observation']")
      assert_no_html(html, "form[action*='exclude_observation']")
    end

    private

    def project
      projects(:rare_fungi_project)
    end

    def obs
      observations(:coprinus_comatus_obs)
    end

    def render_footer(show_excluded:)
      render(Components::Projects::ObsFooter.new(
               project: project, obs: obs, show_excluded: show_excluded
             ))
    end
  end
end
