# frozen_string_literal: true

# Action view for `visual_groups#new`: form + back link.
module Views::Controllers::VisualGroups
  class New < Views::FullPageBase
    prop :visual_model, VisualModel
    prop :visual_group, VisualGroup

    def view_template
      add_new_title(:new_object, :visual_group)

      render(Form.new(@visual_group, visual_model: @visual_model))
      link_to("Back", visual_model_visual_groups_path(@visual_model))
    end
  end
end
