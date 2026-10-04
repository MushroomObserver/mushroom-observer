# frozen_string_literal: true

# Whether this admin hears about what iNaturalist identified (#5416).
# A site admin says a project may be alerted on; each of its admins
# says whether to be one of the people alerted, which is why this is
# here rather than on the site-admin-only External Sites page.
module Projects
  class AlertSubscriptionsController < ApplicationController
    before_action :login_required

    def update
      return unless find_project!
      return must_be_project_admin! unless @project.is_admin?(@user)
      return unless find_project_site!

      # An unchecked box submits the hidden "0", which is present but
      # means no.
      wanted = ActiveModel::Type::Boolean.new.cast(params[:subscribed])
      @project_site.alerts_for(@user, wanted)
      flash_notice(subscribed_notice)
      redirect_to(project_admin_path(project_id: @project.id))
    end

    private

    def subscribed_notice
      if @project_site.alerts?(@user)
        :project_alerts_subscribed.t(project: @project.title)
      else
        :project_alerts_unsubscribed.t(project: @project.title)
      end
    end

    def find_project!
      @project = Project.safe_find(params[:project_id].to_s) ||
                 flash_error_and_goto_index(Project, params[:project_id].to_s)
    end

    # Only a site alerting on can be subscribed to, so a stale form from
    # before a site admin turned it off changes nothing.
    def find_project_site!
      @project_site = @project.project_external_sites.alerting.
                      find_by(id: params[:id])
      return @project_site if @project_site

      flash_error(:project_alerts_not_offered.t)
      redirect_to(project_admin_path(project_id: @project.id))
      nil
    end

    def must_be_project_admin!
      flash_error(:change_member_status_denied.t)
      redirect_to(project_path(@project.id))
    end
  end
end
