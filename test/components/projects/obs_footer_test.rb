# frozen_string_literal: true

require("test_helper")

module Projects
  class ObsFooterTest < ComponentTestCase
    def test_renders_add_button_when_not_in_project
      html = render_footer(in_project: false)

      assert_html(html, "#update_footer_#{obs.id}")
      assert_includes(html, :ADD.l)
      assert_html(html, "form[action*='add_observation']")
      assert_no_html(html, "form[action*='remove_observation']")
    end

    def test_renders_remove_button_when_in_project
      html = render_footer(in_project: true)

      assert_html(html, "#update_footer_#{obs.id}")
      assert_includes(html, :REMOVE.l)
      assert_html(html, "form[action*='remove_observation']")
      assert_no_html(html, "form[action*='add_observation']")
    end

    private

    def project
      projects(:rare_fungi_project)
    end

    def obs
      observations(:coprinus_comatus_obs)
    end

    def render_footer(in_project:)
      render(Components::Projects::ObsFooter.new(
               project: project, obs: obs, in_project: in_project
             ))
    end
  end
end
