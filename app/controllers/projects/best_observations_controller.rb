# frozen_string_literal: true

#  ==== The observation a project puts forward for a name
#
#  show:: redirect to it
#
#  A QR code on a printed label points here rather than at a fixed
#  observation, so the label keeps working when the project gains a
#  better photograph or a better identification of the same mushroom
#  (#5416). What "better" means is `Project::BestObservation`.
#
#  No login: these codes are scanned by whoever walks past the display
#  table. The redirect goes to the `/obs/` form for the same reason --
#  it is the one a logged-out visitor may follow (#5357).
module Projects
  class BestObservationsController < ApplicationController
    def show
      return unless (project = find_project!)
      return unless (name = find_name!(project))

      observation = Project::BestObservation.new(project, name).observation
      return redirect_to_index(project, name) unless observation

      redirect_to(permanent_observation_path(observation.id))
    end

    private

    def find_project!
      Project.safe_find(params[:project_id].to_s) ||
        flash_error_and_goto_index(Project, params[:project_id].to_s)
    end

    def find_name!(project)
      Name.safe_find(params[:name_id].to_s) ||
        flash_error_and_goto_project(project)
    end

    def flash_error_and_goto_project(project)
      flash_error(:runtime_object_not_found.t(type: :name,
                                              id: params[:name_id]))
      redirect_to(project_path(project.id))
      nil
    end

    # Nothing in the project matches, so show what the project does
    # hold for that name rather than an error: the name may have been
    # corrected since the label was printed.
    def redirect_to_index(project, name)
      flash_warning(:project_best_observation_none.t(name: name.text_name,
                                                     project: project.title))
      redirect_to(observations_path(project: project.id, name: name.text_name))
    end
  end
end
