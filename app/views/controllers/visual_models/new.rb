# frozen_string_literal: true

# Action view for `visual_models#new`. Replaces the 4-line
# `new.html.erb` — form (already Phlex) + a back link.
module Views::Controllers::VisualModels
  class New < Views::Base
    prop :visual_model, VisualModel

    def view_template
      add_new_title(:new_object, :VISUAL_MODEL)

      render(Form.new(@visual_model))
      link_to("Back", visual_models_path)
    end
  end
end
