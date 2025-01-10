# frozen_string_literal: true

module Projects
  class ProjectAliasesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params, except: [:index]
    before_action :set_project_alias, only: [:show, :edit, :update, :destroy]
    
    def index
      @project = Project.find(params[:project_id])
      @project_aliases = ProjectAlias.all
      respond_to do |format|
        format.html
        format.json { render json: @project_aliases }
      end
    end
    
    def show
      respond_to do |format|
        format.html
        format.json { render json: @project_alias }
      end
    end
    
    def new
      @project_alias = ProjectAlias.new(project_id: params.require(:project_id))
    end
    
    def edit
    end
    
    def create
      @project_alias = ProjectAlias.new(project_alias_params)
    
      respond_to do |format|
        if @project_alias.save
          format.html { redirect_to @project_alias, notice: 'Project alias was successfully created.' }
          format.json { render json: @project_alias, status: :created, location: @project_alias }
        else
          format.html { render :new }
          format.json { render json: @project_alias.errors, status: :unprocessable_entity }
        end
      end
    end
    
    def update
      respond_to do |format|
        if @project_alias.update(project_alias_params)
          format.html { redirect_to @project_alias, notice: 'Project alias was successfully updated.' }
          format.json { render json: @project_alias }
        else
          format.html { render :edit }
          format.json { render json: @project_alias.errors, status: :unprocessable_entity }
        end
      end
    end
    
    def destroy
      @project_alias.destroy
      respond_to do |format|
        format.html { redirect_to project_aliases_url, notice: 'Project alias was successfully deleted.' }
        format.json { head :no_content }
      end
    end
    
    private
    
    def set_project_alias
      @project_alias = ProjectAlias.find(params[:id])
    end
    
    def project_alias_params
      params.require(:project_alias).permit(:name, :project_id, :target_type, :target_id)
    end
  end
end
