# frozen_string_literal: true

# Admin tab landing page for a project. Renders the project edit
# form (Details sub-tab) plus a Danger Zone section with the Delete
# Project action. Project-admins only.
module Projects
  class AdminController < ApplicationController
    before_action :login_required

    def show
      return unless find_project!
      return must_be_project_admin!(@project.id) unless
        @project.is_admin?(@user)

      compute_form_ivars
      render(Views::Controllers::Projects::Admin::Show.new(
               project: @project, user: @user,
               dates_any: @project_dates_any,
               upload_params: upload_params_hash
             ), layout: true)
    end

    private

    def find_project!
      @project = Project.safe_find(params[:project_id].to_s) ||
                 flash_error_and_goto_index(Project, params[:project_id].to_s)
    end

    def must_be_project_admin!(id)
      flash_error(:change_member_status_denied.t)
      redirect_to(project_path(id))
    end

    # Mirror the ivars and helpers ProjectsController#edit sets up so
    # the embedded ProjectForm has everything it expects.
    def compute_form_ivars
      compute_image_ivars
      @start_date_fixed = @project.start_date.present?
      @end_date_fixed = @project.end_date.present?
      @project_dates_any = !@start_date_fixed && !@end_date_fixed
    end

    def compute_image_ivars
      @licenses = License.available_names_and_ids(@user.license)
      defaults = @project.image ? image_defaults : user_defaults
      (@copyright_holder, @copyright_year, @upload_license_id) = defaults
    end

    def image_defaults
      [@project.image.copyright_holder,
       @project.image.when.year,
       @project.image.license.id]
    end

    def user_defaults
      [@user.legal_name, Time.zone.now.year, @user.license&.id]
    end

    def upload_params_hash
      {
        copyright_holder: @copyright_holder,
        copyright_year: @copyright_year,
        licenses: @licenses,
        upload_license_id: @upload_license_id
      }
    end
  end
end
