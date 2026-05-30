# frozen_string_literal: true

# Action view for `visual_models#show`. Replaces the 2-line
# `show.html.erb` — just renders the visual-group table for the
# current visual model.
module Views::Controllers::VisualModels
  class Show < Views::Base
    prop :visual_model, VisualModel

    def view_template
      render(VisualGroupTable.new(visual_model: @visual_model))
    end
  end
end
