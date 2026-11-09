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
        class: "table-visual-model mb-3 mt-3"
      ) do |t|
        t.column("Name") do |vm|
          Link(type: :get, name: vm.name, target: vm)
        end
        t.column("Groups", align: :center) do |vm|
          CountBadge(count: vm.visual_groups.size, type: :visual_group)
        end
        t.column(nil, align: :center) do |vm|
          Button(type: :edit, target: vm, variant: :strip)
        end
        t.column(nil, align: :center) do |vm|
          Button(type: :delete, target: vm, variant: :strip)
        end
      end
    end
  end
end
