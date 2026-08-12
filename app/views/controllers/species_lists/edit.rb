# frozen_string_literal: true

# Action view for the species_list edit page. Sets page chrome
# (title, context-nav, container width) and delegates body to the
# shared `Form` Phlex class with `button: :update`.
module Views::Controllers::SpeciesLists
  class Edit < Views::FullPageBase
    prop :species_list, ::SpeciesList
    prop :projects, _Array(::Project)
    prop :dubious_where_reasons, _Nilable(_Array(_Tuple(Symbol, Hash)))
    prop :submitted_project_ids, _Nilable(_Array(Integer)) do |value|
      value&.map { |id| Integer(id) }
    end
    prop :user, ::User

    def view_template
      add_edit_title(@species_list)
      add_context_nav(::Tab::SpeciesList::FormEdit.new(list: @species_list))
      container_class(:text)

      render(Views::Controllers::SpeciesLists::Form.new(
               @species_list,
               projects: @projects,
               dubious_where_reasons: @dubious_where_reasons,
               submitted_project_ids: @submitted_project_ids,
               user: @user,
               button: :update
             ))
    end
  end
end
