# frozen_string_literal: true

module Projects
  class AliasesController < ApplicationController
    before_action :login_required
    before_action :set_project_alias, only: [:show, :edit, :update, :destroy]

    # Aliases lives under the project Admin tab now (issue #4148).
    def active_project_tab
      "admin"
    end
    helper_method :active_project_tab

    def index
      @project = Project.find(params[:project_id])
      @project_aliases = ProjectAlias.index_includes.
                         where(project: @project).order(name: :asc).to_a
      respond_to do |format|
        format.html do
          render(Views::Controllers::Projects::Aliases::Index.new(
                   project: @project,
                   project_aliases: @project_aliases
                 ))
        end
      end
    end

    def show
      @project = @project_alias.project
      respond_to do |format|
        format.html do
          render(Views::Controllers::Projects::Aliases::Show.new(
                   project: @project,
                   project_alias: @project_alias
                 ))
        end
      end
    end

    def new
      params.require(:project_id)
      new_params = params.permit(:project_id, :target_type, :target_id)
      @project_alias = ProjectAlias.new(new_params)
      @project = @project_alias.project

      respond_to do |format|
        format.turbo_stream { render_modal_project_alias_form }
        format.html { render_new_view }
      end
    end

    def edit
      @project = @project_alias.project
      respond_to do |format|
        format.turbo_stream { render_modal_project_alias_form }
        format.html { render_edit_view }
      end
    end

    def create
      @project_alias = ProjectAlias.new(project_alias_params)
      @project = @project_alias.project
      err = resolve_verify_target_error(
        @project_alias.verify_target(params[:project_alias][:term])
      )
      respond_to do |format|
        if err.nil? && @project_alias.save
          render_project_alias_created(format)
        else
          flash_and_reload(format, :new, error: err)
        end
      end
    end

    def render_project_alias_created(format)
      format.turbo_stream do
        render_project_alias_target_change(@project_alias.project)
      end
      format.html { project_aliases_redirect(@project_alias.project_id) }
    end

    # ProjectAlias#verify_target returns an unresolved [tag, args]
    # pair (or nil) so a render-facing concern doesn't live on the
    # model -- resolve it here before it gets flashed.
    def resolve_verify_target_error(tag_and_args)
      return nil unless tag_and_args

      tag, args = tag_and_args
      tag.t(**args)
    end

    def flash_and_reload(format, action, error: false)
      flash_error(error) if error
      flash_object_errors(@project_alias)
      format.turbo_stream { reload_modal_project_alias_form }
      format.html { send(:"render_#{action}_view_invalid") }
    end

    def update
      @project = @project_alias.project
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
      # Refetch fresh (non-strict_loading) for the destroy cascade.
      ProjectAlias.find(@project_alias.id).destroy
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

    def render_new_view(status: :ok, **render_opts)
      render(Views::Controllers::Projects::Aliases::New.new(
               project_alias: @project_alias,
               project: @project, user: @user
             ),
             status: status, **render_opts)
    end

    def render_edit_view(status: :ok, **render_opts)
      render(Views::Controllers::Projects::Aliases::Edit.new(
               project_alias: @project_alias,
               project: @project, user: @user
             ),
             status: status, **render_opts)
    end

    def redirect_to_project_aliases
      redirect_to(project_aliases_path(
                    project_id: @project_alias.project_id
                  ),
                  notice: :project_alias_updated.t)
    end

    # Replaces the target widget and the aliases table, then closes
    # and removes the modal. Inlined from the deleted
    # `projects/aliases/_target_update.erb` partial. Emits four
    # turbo_stream actions.
    def render_project_alias_target_change(project)
      project_aliases = project.aliases.includes(:target).order(name: :asc).
                        to_a
      render(turbo_stream: [
               replace_target_alias_widget,
               replace_aliases_table(project_aliases),
               turbo_stream.close_modal(target_change_modal_id),
               turbo_stream.remove(target_change_modal_id)
             ])
    end

    def replace_target_alias_widget
      turbo_stream.replace(
        "target_project_alias_#{@project_alias.target_id}",
        view_context.render(Views::Controllers::Projects::Aliases::Widget.new(
                              project: @project_alias.project,
                              target: @project_alias.target
                            ))
      )
    end

    def replace_aliases_table(project_aliases)
      turbo_stream.replace(
        Views::Controllers::Projects::Aliases::Table::TABLE_ID,
        view_context.render(Views::Controllers::Projects::Aliases::Table.new(
                              project_aliases: project_aliases
                            ))
      )
    end

    # The update action replaces the per-alias modal
    # (`modal_project_alias_<id>`); create / destroy use the shared
    # `modal_project_alias` id.
    def target_change_modal_id
      if action_name == "update"
        "modal_project_alias_#{@project_alias.id}"
      else
        "modal_project_alias"
      end
    end

    def render_modal_project_alias_form
      render(Components::Modal.new(
               type: :turbo_form,
               identifier: modal_identifier,
               title: modal_title,
               user: @user,
               model: @project_alias,
               form_locals: { user: @user }
             ), layout: false) and return
    end

    def reload_modal_project_alias_form
      render_modal_form_reload(
        identifier: modal_identifier,
        form_locals: { model: @project_alias, user: @user }
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
      @project_alias = ProjectAlias.show_includes.find(params[:id])
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
