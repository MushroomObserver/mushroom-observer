# frozen_string_literal: true

# Action view for the species_list new page. Sets page chrome
# (title, context-nav, container width) and delegates body to the
# shared `Form` Phlex class with `button: :create`.
#
# `clone_id` is set when the user lands on `?clone=<id>` — the form
# pre-populates from another species_list.
module Views::Controllers::SpeciesLists
  class New < Views::FullPageBase
    prop :species_list, ::SpeciesList
    prop :projects, _Array(::Project)
    prop :dubious_where_reasons, _Nilable(_Array(_Tuple(Symbol, Hash)))
    prop :submitted_project_ids, _Nilable(_Array(Integer)), &TO_ID_ARRAY
    prop :user, ::User
    # Comes from `params[:clone]` (always a String, or absent) --
    # coerced so a non-numeric value fails loudly here instead of
    # silently round-tripping into SpeciesList.safe_find later.
    prop :clone_id, _Nilable(Integer), default: nil, &TO_ID

    def view_template
      add_new_title(:create_object, :species_list)
      add_context_nav(
        ::Tab::SpeciesList::FormNew.new(index_filter: index_filter)
      )
      container_class(:text)

      render(Views::Controllers::SpeciesLists::Form.new(
               @species_list,
               projects: @projects,
               dubious_where_reasons: @dubious_where_reasons,
               submitted_project_ids: @submitted_project_ids,
               user: @user,
               button: :create,
               clone_id: @clone_id,
               turbo: true
             ))
    end
  end
end
