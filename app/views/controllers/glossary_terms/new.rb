# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  # Wrap of `GlossaryTerms::Form` for the create-new flow.
  class New < Views::FullPageBase
    prop :glossary_term, ::GlossaryTerm
    prop :copyright_holder, _Nilable(::String), default: nil
    prop :copyright_year, _Nilable(::Integer), default: nil
    # `License.available_names_and_ids` returns an array of
    # `[String, Integer]` pairs; type as an Array of Array.
    prop :licenses, _Nilable(_Array(::Array)), default: nil
    # `License#id` is Integer in normal flow, but failed-form reloads
    # round-trip the param through
    # `params[:glossary_term][:upload][:license_id]` as a String.
    prop :upload_license_id, _Nilable(_Union(::Integer, ::String)),
         default: nil

    def view_template
      add_new_title(:create_object, :GLOSSARY_TERM)
      add_context_nav(::Tab::GlossaryTerm::FormNew.new)

      render(Form.new(
               @glossary_term,
               enctype: "multipart/form-data",
               upload_params: {
                 copyright_holder: @copyright_holder,
                 copyright_year: @copyright_year,
                 licenses: @licenses,
                 upload_license_id: @upload_license_id
               }
             ))
    end
  end
end
