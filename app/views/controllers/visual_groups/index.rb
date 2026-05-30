# frozen_string_literal: true

# Action view for `visual_groups#index`. Replaces the 2-line
# `index.html.erb` — just renders the shared visual-group table for
# the current visual model.
module Views::Controllers::VisualGroups
  class Index < Views::Base
    prop :visual_model, VisualModel

    def view_template
      render(Views::Controllers::VisualModels::VisualGroupTable.new(
               visual_model: @visual_model
             ))
    end
  end
end
