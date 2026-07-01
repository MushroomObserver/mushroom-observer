# frozen_string_literal: true

module Views::Controllers::InatImports
  # iNat import-confirmation page. Renders the form (already a
  # Phlex `ConfirmForm`) with expected import count + breakdown
  # numbers passed through.
  class Confirm < Views::FullPageBase
    prop :confirm_form, ::FormObject::InatImportConfirm
    prop :expected, _Nilable(::Integer), default: nil
    prop :unlicensed_obs, _Nilable(::Integer), default: nil
    prop :inat_import, ::InatImport
    prop :requested, _Nilable(::Integer), default: nil
    prop :after_taxon, _Nilable(::Integer), default: nil
    prop :estimate_with_date, _Nilable(::Integer), default: nil

    def view_template
      add_page_title(:inat_import_confirm_title.l)
      add_context_nav(::Tab::InatImport::FormNew.new)

      render(ConfirmForm.new(
               @confirm_form,
               expected: @expected,
               unlicensed_obs: @unlicensed_obs,
               breakdown: {
                 inat_import: @inat_import,
                 requested: @requested,
                 after_taxon: @after_taxon,
                 estimate_with_date: @estimate_with_date
               }
             ))
    end
  end
end
