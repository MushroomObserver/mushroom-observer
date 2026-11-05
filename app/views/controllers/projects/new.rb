# frozen_string_literal: true

module Views::Controllers::Projects
  # Phlex view for the new project form page.
  class New < Views::FullPageBase
    prop :project, ::Project
    prop :dates_any, _Boolean
    prop :upload_params, Hash
    prop :dubious_where_reasons, _Nilable(_Array(_Tuple(Symbol, Hash))),
         default: nil
    prop :raw_place_name, _Nilable(String), default: nil

    def view_template
      add_new_title(:create_object, :project)
      add_context_nav(::Tab::Project::FormNew.new)

      render(Views::Controllers::Projects::Form.new(
               @project,
               enctype: "multipart/form-data",
               dates_any: @dates_any,
               upload_params: @upload_params,
               dubious_where_reasons: @dubious_where_reasons,
               raw_place_name: @raw_place_name
             ))
    end
  end
end
