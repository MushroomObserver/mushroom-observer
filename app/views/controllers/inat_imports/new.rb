# frozen_string_literal: true

module Views::Controllers::InatImports
  # Phlex view for the iNat import new/create page.
  # Sets page title and context nav, then renders the
  # form component.
  class New < Views::Base
    def initialize(form:, super_importer: false)
      super()
      @form = form
      @super_importer = super_importer
    end

    def view_template
      add_page_title(:inat_import_create_title.l)
      add_context_nav(Tab::InatImport::FormNew.new)
      render(Views::Controllers::InatImports::Form.new(
               @form, super_importer: @super_importer
             ))
    end
  end
end
