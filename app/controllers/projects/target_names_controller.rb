# frozen_string_literal: true

module Projects
  class TargetNamesController < ApplicationController
    before_action :login_required
    before_action :set_project
    before_action :require_admin

    def create
      names = parse_names_from_params
      if names.any?
        add_names(names)
      else
        flash_error(:project_target_name_not_found.t)
      end
      respond_to do |format|
        format.turbo_stream { render_checklist_update }
        format.html { redirect_to_checklist }
      end
    end

    def destroy
      name = Name.safe_find(params[:id])
      if name
        @project.remove_target_name(name)
        flash_notice(
          :project_target_name_removed.t(name: name.text_name)
        )
      else
        flash_error(:project_target_name_not_found.t)
      end
      respond_to do |format|
        format.turbo_stream { render_checklist_update }
        format.html { redirect_to_checklist }
      end
    end

    private

    def set_project
      @project = find_or_goto_index(Project, params[:project_id])
    end

    def require_admin
      return if @project&.is_admin?(@user)

      flash_error(:permission_denied.t)
      redirect_to_checklist
    end

    def redirect_to_checklist
      redirect_to(checklist_path(project_id: @project.id))
    end

    # Parse name input: supports comma-separated, newline-separated,
    # and pasted checklist format with counts like "Name (3) * +"
    def parse_names_from_params
      raw = params[:names].to_s
      raw.split(/[,\n]/).filter_map { |entry| lookup_name(entry) }
    end

    # Strip checklist annotations: "(count)", "*", "+"
    def lookup_name(entry)
      cleaned = entry.strip.
                gsub(/\s*\(\d+\)\s*/, " ").
                gsub(/\s*[*+]\s*/, " ").
                strip
      return if cleaned.blank?

      Name.find_by(text_name: cleaned)
    end

    def add_names(names)
      added = names.select do |name|
        next false if @project.target_names.include?(name)

        @project.add_target_name(name)
        true
      end
      return unless added.any?

      list = added.map(&:text_name).join(", ")
      flash_notice(
        :project_target_names_added.t(names: list)
      )
    end

    def render_checklist_update
      data = Checklist::ForProject.new(@project)
      render(
        partial: "projects/target_names/checklist_update",
        locals: { project: @project, data: data, user: @user }
      )
    end
  end
end
