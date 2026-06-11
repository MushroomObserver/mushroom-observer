# frozen_string_literal: true

module Views::Controllers::Checklists
  # Bundles the rendering context for a checklist page: the viewer, plus
  # the scope indicators (project / user / location / species_list) that
  # determine link targets. Keeps component/view constructors narrow.
  Context = Struct.new(
    :user, :project, :show_user, :location, :species_list,
    keyword_init: true
  ) do
    # Argument accepted by `Checklists::Panel#taxon_link_path`.
    def link_params
      [show_user, project, location, species_list]
    end

    def admin?
      project&.is_admin?(user)
    end
  end
end
