# frozen_string_literal: true

module Views::Controllers::InatImports
  # Phlex view for the iNat import new/create page.
  # Sets page title and context nav, then renders the
  # form component.
  class New < Views::FullPageBase
    prop :form, ::FormObject::InatImport
    prop :super_importer, _Boolean, default: false
    prop :admin, _Boolean, default: false
    prop :has_prior_imports, _Boolean, default: false

    def view_template
      add_page_title(:inat_import_create_title.l)
      add_context_nav(
        Tab::InatImport::FormNew.new(has_prior_imports: @has_prior_imports)
      )
      render(Views::Controllers::InatImports::Form.new(
               @form, super_importer: @super_importer, admin: @admin,
                      local: false
             ))
    end
  end
end
