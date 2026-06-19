# frozen_string_literal: true

# Action view for `visual_models#edit`: form + show / back links.
module Views::Controllers::VisualModels
  class Edit < Views::FullPageBase
    prop :visual_model, VisualModel

    def view_template
      add_edit_title(@visual_model)

      render(Form.new(@visual_model))
      link_to("Show", visual_model_path(@visual_model))
      plain(" | ")
      link_to("Back", visual_models_path)
    end
  end
end
