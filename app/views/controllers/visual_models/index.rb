# frozen_string_literal: true

# Action view for `visual_models#index`.
# admin-only page listing every visual model with edit / destroy
# links + a "New Visual Model" link.
module Views::Controllers::VisualModels
  class Index < Views::FullPageBase
    prop :visual_models, _Array(VisualModel)

    def view_template
      h1 { plain("Visual Models") }
      render(Components::Table.new(
               @visual_models,
               class: "table-striped table-visual-model mb-3 mt-3"
             )) do |t|
        t.column("Name", width: "33%") { |vm| link_to(vm.name, vm) }
        t.column(nil, width: "33%") do |vm|
          link_to("Edit", edit_visual_model_path(vm))
        end
        t.column(nil, width: "33%") { |vm| render_destroy_link(vm) }
      end
      br
      link_to("New Visual Model", new_visual_model_path)
    end

    private

    def render_destroy_link(visual_model)
      link_to("Destroy", visual_model_path(visual_model),
              method: :delete,
              data: { confirm: :are_you_sure.t })
    end
  end
end
