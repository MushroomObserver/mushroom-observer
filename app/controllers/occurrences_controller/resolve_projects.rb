# frozen_string_literal: true

# Handles POST from the project membership confirmation modal.
# GET renders the edit page with the modal overlaid.
module OccurrencesController::ResolveProjects
  def resolve_projects
    return unless find_occurrence!

    @gaps = @occurrence.project_membership_gaps
    if @gaps.empty?
      redirect_to(occurrence_path(@occurrence))
      return
    end

    if request.post?
      handle_resolution
    else
      @project_gaps = @gaps
      render_edit_page
    end
  end

  private

  def handle_resolution
    if params[:resolution] == "add_all"
      projects = @gaps[:projects] || []
      @occurrence.add_all_to_collections(projects: projects)
      flash_notice(:occurrence_resolve_projects_all_done.t(
                     count: projects.size
                   ))
    end
    redirect_to(occurrence_path(@occurrence))
  end
end
