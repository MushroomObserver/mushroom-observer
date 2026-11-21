# frozen_string_literal: true

# Action view for `visual_models#index`.
# Lists every visual model with edit / destroy links + a "New
# Visual Model" link.
module Views::Controllers::VisualModels
  class Index < Views::FullPageBase
    prop :visual_models, _Array(VisualModel)

    def view_template
      Table(
        @visual_models,
        variant: :striped, align_middle: true,
        identifier: "visual-model"
      ) do |t|
        t.column("Name") do |vm|
          Link(type: :get, name: vm.name, target: vm)
        end
        t.column("Groups", align: :center) do |vm|
          Badge(variant: :count, count: vm.visual_groups.size,
                type: :visual_group)
        end
        t.column(:actions.ti, align: :center) { |vm| render_actions(vm) }
      end
    end

    private

    def render_actions(visual_model)
      InlineCRUDLinks(target: visual_model, user: current_user)
    end
  end
end
