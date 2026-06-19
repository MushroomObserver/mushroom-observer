# frozen_string_literal: true

# Action view for `visual_groups#index`. Replaces the 2-line
# `index.html.erb` — just renders the shared visual-group table for
# the current visual model.
module Views::Controllers::VisualGroups
  class Index < Views::FullPageBase
    prop :visual_model, VisualModel
    prop :visual_groups, _Array(VisualGroup)

    def view_template
      add_show_title(@visual_model)
      render(Views::Controllers::VisualModels::VisualGroupTable.new(
               visual_model: @visual_model,
               visual_groups: @visual_groups
             ))
    end
  end
end
