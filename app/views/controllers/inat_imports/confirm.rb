# frozen_string_literal: true

module Views::Controllers::InatImports
  # iNat import-confirmation page. Renders the form (already a
  # Phlex `ConfirmForm`) with import estimate + unlicensed-obs
  # numbers passed through.
  class Confirm < Views::FullPageBase
    prop :confirm_form, ::FormObject::InatImportConfirm
    prop :estimate, ::Integer
    # `fetch_unlicensed_*_count` returns nil when the iNat licensed-
    # estimate call errors; ConfirmForm handles nil.
    prop :unlicensed_obs, _Nilable(::Integer), default: nil
    prop :inat_import, ::InatImport

    def view_template
      add_page_title(:inat_import_confirm_title.l)
      add_context_nav(::Tab::InatImport::FormNew.new)

      render(ConfirmForm.new(@confirm_form,
                             estimate: @estimate,
                             unlicensed_obs: @unlicensed_obs,
                             inat_import: @inat_import))
    end
  end
end
