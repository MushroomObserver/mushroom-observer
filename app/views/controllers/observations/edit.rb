# frozen_string_literal: true

# Action template for `ObservationsController#edit` — the
# "edit this observation" page. Sets the page title, action-nav,
# and container width, then renders `Observations::Form` in
# `:update` mode with the observation's edit-time state.
module Views::Controllers::Observations
  class Edit < Views::FullPageBase
    prop :observation, ::Observation
    prop :user, _Nilable(::User), default: nil
    prop :location, _Nilable(::Location), default: nil
    prop :good_images, _Array(::Image), default: -> { [] }
    prop :sibling_images, _Array(::Image), default: -> { [] }
    prop :exif_data, Hash, default: -> { {} }
    prop :dubious_where_reasons, _Nilable(_Array(_Tuple(Symbol, Hash))),
         default: nil
    prop :place_name, _Nilable(String), default: nil
    prop :projects, _Array(::Project), default: -> { [] }
    prop :submitted_project_ids, _Nilable(_Array(Integer)),
         default: nil, &TO_ID_ARRAY
    prop :lists, _Array(::SpeciesList), default: -> { [] }
    prop :submitted_list_ids, _Nilable(Array), default: nil
    prop :error_checked_projects, _Array(::Project), default: -> { [] }
    prop :suspect_checked_projects, _Array(::Project), default: -> { [] }
    prop :cross_prefix_projects, _Array(::Project), default: -> { [] }
    prop :slip_target_project, _Nilable(::Project), default: nil
    prop :field_code, _Nilable(String), default: nil

    def view_template
      add_edit_title(@observation, user: @user)
      add_context_nav(Tab::Observation::FormEdit.new(observation: @observation))
      container_class(:wide)

      render(Form.new(
               @observation,
               mode: :update,
               turbo: true,
               user: @user,
               location: @location,
               good_images: @good_images,
               sibling_images: @sibling_images,
               exif_data: @exif_data,
               dubious_where_reasons: @dubious_where_reasons,
               place_name: @place_name,
               projects: @projects,
               submitted_project_ids: @submitted_project_ids,
               lists: @lists,
               submitted_list_ids: @submitted_list_ids,
               error_checked_projects: @error_checked_projects,
               suspect_checked_projects: @suspect_checked_projects,
               cross_prefix_projects: @cross_prefix_projects,
               slip_target_project: @slip_target_project,
               field_code: @field_code
             ))
    end
  end
end
