# frozen_string_literal: true

# Form object for the species-list project-membership management
# form (`SpeciesLists::ProjectsController#edit/update`). Wraps the
# admin's choice of which kinds of objects (list / observations /
# images) to attach or remove, plus the array of project ids the
# operation targets.
class FormObject::SpeciesListProjects < FormObject::Base
  attribute :objects_list, :string
  attribute :objects_obs, :string
  attribute :objects_img, :string
  attribute :project_ids, default: -> { [] }
end
