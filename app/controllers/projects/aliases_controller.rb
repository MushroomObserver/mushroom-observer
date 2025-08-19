# frozen_string_literal: true

module Projects
  class AliasesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params, except: [:index]
    before_action :set_project_alias, only: [:show, :edit, :update, :destroy]

    def index
      @project = Project.find(params[:project_id])
      @project_aliases = ProjectAlias.where(project: @project).order(name: :asc)
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
      new_params = params.permit(:project_id, :target_type, :target_id)
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
      err = @project_alias.verify_target(params[:project_alias][:term])
      respond_to do |format|
        if err.nil? && @project_alias.save
          format.turbo_stream do
            render_project_alias_target_change(@project_alias.project)
          end
          format.html do
            project_aliases_redirect(@project_alias.project_id)
          end
        else
          flash_and_reload(format, :new, error: err)
        end
      end
    end

    def flash_and_reload(format, action, error: false)
      flash_error(error) if error
      @project_alias.errors.each { |err| flash_error(err.full_message) }
      format.turbo_stream { reload_modal_project_alias_form }
      format.html { render(action) }
    end

    def update
      respond_to do |format|
        if @project_alias.update(project_alias_params)
          format.turbo_stream do
            render_project_alias_target_change(@project_alias.project)
          end
          format.html do
            redirect_to_project_aliases
          end
        else
          flash_and_reload(format, :edit)
        end
      end
    end

    def destroy
      project = @project_alias.project
      @project_alias.destroy
      respond_to do |format|
        format.html do
          redirect_to(project_aliases_path(project_id: project&.id),
                      notice: :project_alias_destroyed.t)
        end
        format.turbo_stream do
          render_project_alias_target_change(project)
        end
      end
    end

    private

    def redirect_to_project_aliases
      redirect_to(project_aliases_path(
                    project_id: @project_alias.project_id
                  ),
                  notice: :project_alias_updated.t)
    end

    def render_project_alias_target_change(project)
      project_aliases = project.aliases.order(name: :asc)
      render(
        partial: "projects/aliases/target_update",
        locals: { identifier: "project_alias", project_aliases: }
      ) and return
    end

    def render_modal_project_alias_form
      render(
        partial: "shared/modal_form",
        locals: { title: modal_title, identifier: modal_identifier,
                  user: @user, form: "projects/aliases/form",
                  form_locals: { project_alias: @project_alias } }
      ) and return
    end

    def reload_modal_project_alias_form
      render(
        partial: "shared/modal_form_reload",
        locals: { identifier: modal_identifier,
                  user: @user, form: "projects/aliases/form",
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

    def project_aliases_redirect(project_id)
      redirect_to(project_aliases_path(project_id:),
                  notice: :project_alias_created.t)
    end

    def set_project_alias
      @project_alias = ProjectAlias.find(params[:id])
    end

    def project_alias_params
      result = params.require(:project_alias).permit(:name, :project_id,
                                                     :target_type, :target_id,
                                                     :location_id, :user_id)
      # Autocompleter automatically uses location_id and user_id, but
      # doing the mapping to target_id in the model causes
      # AbstractModel.set_user_and_autolog to try to set the user_id
      # which it shouldn't.  So clean up the params here.
      update_target(result, :location_id)
      update_target(result, :user_id)
      result
    end

    def update_target(result, field)
      return unless result.include?(field)

      result[:target_id] = result[field]
      result.delete(field)
    end
  end
end
