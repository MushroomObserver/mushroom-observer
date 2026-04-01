# frozen_string_literal: true

module Views
  module Controllers
    module InatImports
      # Phlex view for the iNat import new/create page.
      # Sets page title and context nav, then renders the
      # form component.
      class New < Views::Base
        register_output_helper :add_page_title
        register_output_helper :add_context_nav
        register_value_helper :inat_import_form_new_tabs

        def initialize(form:, super_importer: false)
          super()
          @form = form
          @super_importer = super_importer
        end

        def view_template
          add_page_title(:inat_import_create_title.l)
          add_context_nav(inat_import_form_new_tabs)
          render(Components::InatImportForm.new(
                   @form, super_importer: @super_importer
                 ))
        end
      end
    end
  end
end
