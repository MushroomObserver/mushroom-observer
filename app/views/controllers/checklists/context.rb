# frozen_string_literal: true

module Views::Controllers::Checklists
  # Bundles the rendering context for a checklist page: the viewer, plus
  # the scope indicators (project / user / location / species_list) that
  # determine link targets. Keeps component/view constructors narrow.
  # `logged_out` is separate from `user` because the Missing Taxa panel
  # deliberately omits `user` (to hide admin tools) for logged-in
  # viewers too. Logged-out pages render taxa as text, not links, to
  # keep crawlers off the observation searches.
  Context = Struct.new(
    :user, :project, :show_user, :location, :species_list, :logged_out,
    keyword_init: true
  ) do
    # Argument accepted by `Checklists::Panel#taxon_link_path`.
    def link_params
      [show_user, project, location, species_list]
    end

    # Project admin tools (target-names widget, remove buttons) belong
    # to the project-scoped checklist only -- a species-list checklist
    # may carry a project purely as banner context.
    def admin?
      species_list.nil? && project&.is_admin?(user)
    end
  end
end
