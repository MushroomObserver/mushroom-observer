# frozen_string_literal: true

# Action view for `visual_models#new`: form + back link.
module Views::Controllers::VisualModels
  class New < Views::FullPageBase
    prop :visual_model, VisualModel

    def view_template
      add_new_title(:new_object, :visual_model)

      render(Form.new(@visual_model))
      Link(type: :get, name: "Back", target: visual_models_path)
    end
  end
end
