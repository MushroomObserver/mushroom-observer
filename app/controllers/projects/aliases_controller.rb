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
        format.json { render(json: @project_aliases) }
      end
    end

    def show
      respond_to do |format|
        format.html
        format.json { render(json: @project_alias) }
      end
    end

    def new
      @project_alias = ProjectAlias.new(project_id: params.require(:project_id))
    end

    def edit; end

    def create
      @project_alias = ProjectAlias.new(project_alias_params)

      respond_to do |format|
        if @project_alias.save
          format.html do
            project_alias_redirect(@project_alias)
          end
          format.json do
            render(json: @project_alias, status: :created,
                   location: @project_alias)
          end
        else
          format.html { render(:new) }
          format.json do
            render(json: @project_alias.errors, status: :unprocessable_entity)
          end
        end
      end
    end

    def update
      respond_to do |format|
        if @project_alias.update(project_alias_params)
          format.html do
            redirect_to(project_alias_path(
                          project_id: @project_alias.project_id,
                          id: @project_alias.id
                        ),
                        notice: :project_alias_updated.t)
          end
          format.json { render(json: @project_alias) }
        else
          format.html { render(:edit) }
          format.json do
            render(json: @project_alias.errors, status: :unprocessable_entity)
          end
        end
      end
    end

    def destroy
      project_id = @project_alias.project_id
      @project_alias.destroy
      respond_to do |format|
        format.html do
          redirect_to(project_aliases_pat(project_id:),
                      notice: :project_alias_deleted.t)
        end
        format.json { head(:no_content) }
      end
    end

    private

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
