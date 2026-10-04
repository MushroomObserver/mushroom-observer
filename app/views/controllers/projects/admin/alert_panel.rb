# frozen_string_literal: true

module Views::Controllers::Projects::Admin
  # Whether this admin hears about what iNaturalist identified (#5416).
  # Each site configured for alerting gets a line saying so and a
  # checkbox for the admin reading the page; a site a project is not
  # alerting on is named too, so an admin can see the setting exists
  # and that nothing is being sent.
  class AlertPanel < Views::Base
    prop :project, ::Project
    prop :user, ::User

    def view_template
      return if sites.empty?

      Panel(panel_class: "panel-default mt-4",
            panel_id: "project_alerts") do |p|
        p.with_heading { strong { plain(:project_alerts_heading.l) } }
        p.with_body { sites.each { |site| render_site(site) } }
      end
    end

    private

    def sites
      @sites ||= @project.project_external_sites.
                 includes(:external_site).to_a
    end

    def render_site(project_site)
      name = project_site.external_site.name
      return render_off(name) unless project_site.alerting?

      render(Form.new(project_site, project: @project, user: @user,
                                    site_name: name))
    end

    def render_off(name)
      p { :project_alerts_off.t(site: name) }
    end
  end
end
