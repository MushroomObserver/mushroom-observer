# frozen_string_literal: true

module Projects
  class AliasesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params, except: [:index]
    before_action :set_project_alias, only: [:show, :edit, :update, :destroy]

    def index
      @project = Project.find(params[:project_id])
      @project_aliases = ProjectAlias.all
      respond_to do |format|
        format.html
      end
    end

    def show
      respond_to do |format|
        format.html
      end
    end

    def new
      params.require(:project_id)
      new_params = params.permit(:project_id, :target_type, :target_id,
                                 :user_id, :location_id)
      @project_alias = ProjectAlias.new(new_params)

      respond_to do |format|
        format.turbo_stream { render_modal_project_alias_form }
        format.html
      end
    end

    def edit
      respond_to do |format|
        format.turbo_stream { render_modal_project_alias_form }
        format.html
      end
    end

    def create
      @project_alias = ProjectAlias.new(project_alias_params)

      respond_to do |format|
        if @project_alias.save
          format.turbo_stream do
            render_project_alias_user_change
          end
          format.html do
            project_alias_redirect(@project_alias)
          end
        else
          flash_and_reload(format, :new)
        end
      end
    end

    def flash_and_reload(format, action)
      @project_alias.errors.each { |err| flash_error(err.full_message) }
      format.turbo_stream { reload_modal_project_alias_form }
      format.html { render(action) }
    end

    def update
      respond_to do |format|
        if @project_alias.update(project_alias_params)
          format.turbo_stream do
            render_project_alias_user_change
          end
          format.html do
            redirect_to_project_alias_show
          end
        else
          flash_and_reload(format, :edit)
        end
      end
    end

    def destroy
      project_id = @project_alias.project_id
      @project_alias.destroy
      respond_to do |format|
        format.html do
          redirect_to(project_aliases_path(project_id:),
                      notice: :project_alias_destroyed.t)
        end
        format.turbo_stream do
          render_project_alias_user_change
        end
      end
    end

    private

    def redirect_to_project_alias_show
      redirect_to(project_alias_path(
                    project_id: @project_alias.project_id,
                    id: @project_alias.id
                  ),
                  notice: :project_alias_updated.t)
    end

    def render_project_alias_user_change
      render(
        partial: "projects/aliases/user_update",
        locals: { identifier: "project_alias" }
      ) and return
    end

    def render_modal_project_alias_form
      render(
        partial: "shared/modal_form",
        locals: { title: modal_title, identifier: modal_identifier,
                  form: "projects/aliases/form", project_alias: @project_alias }
      ) and return
    end

    def reload_modal_project_alias_form
      render(
        partial: "shared/modal_form_reload",
        locals: { identifier: modal_identifier,
                  form: "projects/aliases/form",
                  form_locals: { project_alias: @project_alias } }
      ) and return true
    end

    def modal_identifier
      case action_name
      when "new", "create"
        "project_alias"
      when "edit", "update"
        "project_alias_#{@project_alias.id}"
      end
    end

    def modal_title
      case action_name
      when "new", "create"
        :project_alias_new.l
      when "edit", "update"
        :project_alias_edit.l(name: @project_alias.name)
      end
    end

    def project_alias_redirect(project_alias)
      redirect_to(project_alias_path(
                    project_id: project_alias.project_id,
                    id: project_alias.id
                  ),
                  notice: :project_alias_created.t)
    end

    def set_project_alias
      @project_alias = ProjectAlias.find(params[:id])
    end

    def project_alias_params
      params.require(:project_alias).permit(:name, :project_id, :target_type,
                                            :location_id, :user_id)
    end
  end
end
