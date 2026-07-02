# frozen_string_literal: true

module Views::Controllers::InatImports
  # Phlex view for the iNat import new/create page.
  # Sets page title and context nav, then renders the
  # form component.
  class New < Views::FullPageBase
    def initialize(form:, super_importer: false, admin: false,
                   has_prior_imports: false)
      super()
      @form = form
      @super_importer = super_importer
      @admin = admin
      @has_prior_imports = has_prior_imports
    end

    def view_template
      add_page_title(:inat_import_create_title.l)
      add_context_nav(
        Tab::InatImport::FormNew.new(has_prior_imports: @has_prior_imports)
      )
      render(Views::Controllers::InatImports::Form.new(
               @form, super_importer: @super_importer, admin: @admin
             ))
    end
  end
end
