# frozen_string_literal: true

# Action template for `ObservationsController#new` — the
# "create a new observation" page. Sets the page title, action-nav,
# and container width, then renders `Observations::Form` in
# `:create` mode with the initial form state.
module Views::Controllers::Observations
  class New < Views::Base
    prop :observation, ::Observation
    prop :user, _Nilable(::User), default: nil
    prop :location, _Nilable(::Location), default: nil
    prop :good_images, _Array(::Image), default: -> { [] }
    prop :exif_data, Hash, default: -> { {} }
    prop :given_name, _Nilable(String), default: nil
    prop :place_name, _Nilable(String), default: nil
    prop :default_place_name, _Nilable(String), default: nil
    prop :dubious_where_reasons, _Nilable(Array), default: nil
    prop :vote, _Nilable(::Vote), default: nil
    prop :names, _Nilable(Array), default: nil
    prop :valid_names, _Nilable(Array), default: nil
    prop :reasons, _Nilable(Hash), default: nil
    prop :suggest_corrections, _Union(_Boolean, ::Name), default: false
    prop :parent_deprecated, _Union(_Boolean, ::Name), default: false
    prop :collectors_name, _Nilable(String), default: nil
    prop :collectors_number, _Nilable(String), default: nil
    prop :herbarium_name, _Nilable(String), default: nil
    prop :herbarium_id, _Nilable(Integer), default: nil
    prop :accession_number, _Nilable(String), default: nil
    prop :projects, _Array(::Project), default: -> { [] }
    prop :submitted_project_ids, _Nilable(Array), default: nil
    prop :lists, _Array(::SpeciesList), default: -> { [] }
    prop :submitted_list_ids, _Nilable(Array), default: nil
    prop :error_checked_projects, _Array(::Project), default: -> { [] }
    prop :suspect_checked_projects, _Array(::Project), default: -> { [] }
    prop :field_code, _Nilable(String), default: nil
    prop :field_code_locked, _Boolean, default: false

    def view_template
      add_new_title(:create_object, :OBSERVATION)
      add_context_nav(Tab::Observation::FormNew.new(q_param: q_param))
      container_class(:wide)

      render(Form.new(@observation, **form_attrs))
    end

    private

    def form_attrs
      {
        mode: :create,
        user: @user,
        location: @location,
        good_images: @good_images,
        exif_data: @exif_data,
        given_name: @given_name,
        place_name: @place_name,
        default_place_name: @default_place_name,
        dubious_where_reasons: @dubious_where_reasons,
        vote: @vote,
        names: @names,
        valid_names: @valid_names,
        reasons: @reasons,
        suggest_corrections: @suggest_corrections,
        parent_deprecated: @parent_deprecated,
        collectors_name: @collectors_name,
        collectors_number: @collectors_number,
        herbarium_name: @herbarium_name,
        herbarium_id: @herbarium_id,
        accession_number: @accession_number,
        projects: @projects,
        submitted_project_ids: @submitted_project_ids,
        lists: @lists,
        submitted_list_ids: @submitted_list_ids,
        error_checked_projects: @error_checked_projects,
        suspect_checked_projects: @suspect_checked_projects,
        field_code: @field_code,
        field_code_locked: @field_code_locked
      }
    end
  end
end
