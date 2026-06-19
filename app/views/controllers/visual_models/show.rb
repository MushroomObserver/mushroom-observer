# frozen_string_literal: true

# Action view for `visual_models#show`: renders the visual-group
# table for the current visual model.
module Views::Controllers::VisualModels
  class Show < Views::FullPageBase
    prop :visual_model, VisualModel
    prop :visual_groups, _Array(VisualGroup)

    def view_template
      add_show_title(@visual_model)
      render(VisualGroupTable.new(visual_model: @visual_model,
                                  visual_groups: @visual_groups))
    end
  end
end
