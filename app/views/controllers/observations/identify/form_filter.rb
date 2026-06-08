# frozen_string_literal: true

# Rendered in the top-nav of identify pages
# (`Observations::IdentifyController`). Wraps `Identify::Form` with
# its `FormObject::IdentifyFilter` built from `params[:filter]`.
# Replaces the `_form_identify_filter.html.erb` partial.
module Views::Controllers::Observations::Identify
  class FormFilter < Views::Base
    def view_template
      render(Form.new(
               FormObject::IdentifyFilter.new(
                 type: params.dig(:filter, :type),
                 term: params.dig(:filter, :term)
               )
             ))
    end
  end
end
