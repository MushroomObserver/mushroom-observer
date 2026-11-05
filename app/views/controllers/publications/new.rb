# frozen_string_literal: true

module Views::Controllers::Publications
  # New-publication page — chrome + the existing `Publications::Form`.
  class New < Views::FullPageBase
    prop :publication, ::Publication

    def view_template
      add_new_title(:create_object, :publication)
      add_context_nav(::Tab::Publication::FormNew.new)

      render(Form.new(@publication))
    end
  end
end
