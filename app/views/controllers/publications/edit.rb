# frozen_string_literal: true

module Views::Controllers::Publications
  # Edit-publication page — chrome + the existing `Publications::Form`.
  class Edit < Views::Base
    prop :publication, ::Publication

    def view_template
      add_edit_title(@publication)
      add_context_nav(::Tab::Publication::FormEdit.new(
                        publication: @publication
                      ))

      render(Form.new(@publication))
    end
  end
end
