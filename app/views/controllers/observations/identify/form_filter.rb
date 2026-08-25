# frozen_string_literal: true

# Rendered in the top-nav of identify pages
# (`Observations::IdentifyController`). Wraps `Identify::Form` with
# its `FormObject::IdentifyFilter` built from `params[:identify_filter]`.
module Views::Controllers::Observations::Identify
  class FormFilter < Views::Base
    def view_template
      filter = params.permit(identify_filter: [:type, :term])[:identify_filter]
      render(Form.new(
               FormObject::IdentifyFilter.new(
                 type: filter&.dig(:type),
                 term: filter&.dig(:term)
               ),
               turbo: true
             ))
    end
  end
end
