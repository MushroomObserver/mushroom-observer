# frozen_string_literal: true

# Table of a `VisualModel`'s visual groups + per-group included /
# excluded counts + edit / destroy links. Rendered by both the
# visual-model show page and the visual-group index page (both pages
# are effectively "this visual model's groups").
#
# Lives under `visual_models/` because it's a visual-model-scoped table,
# not a generic table — the `shared/` path was a hangover from the rails
# scaffold's habit of dumping such partials there.
module Views::Controllers::VisualModels
  class VisualGroupTable < Views::Base
    prop :visual_model, VisualModel
    # Pre-loaded by the host controllers (`VisualGroupsController#index`
    # / `VisualModelsController#show`); the view no longer runs the
    # `.order(:name)` query itself.
    prop :visual_groups, _Array(VisualGroup)

    def view_template
      render_top_nav
      h3 { plain("Visual Groups") }
      render_table
    end

    # Both callers (`VisualGroups::Index`, `VisualModels::Show`)
    # render this table as the entire page body. Each calls
    # `add_show_title(@visual_model)` itself so the page-chrome
    # call sits on the action view, not on the sub-partial.

    private

    def render_table
      render(Components::Table.new(
               groups, class: "table-striped table-visual-model mb-3 mt-3"
             )) do |t|
        define_columns(t)
      end
    end

    def define_columns(table)
      define_name_column(table)
      define_count_columns(table)
      define_action_columns(table)
    end

    def define_name_column(table)
      table.column(:NAME.t) { |g| link_to(g.name, visual_group_path(g)) }
    end

    def define_count_columns(table)
      table.column(:visual_group_included.t) do |g|
        count_in(included_counts, g)
      end
      table.column(:visual_group_excluded.t) do |g|
        count_in(excluded_counts, g)
      end
    end

    def define_action_columns(table)
      table.column(:EDIT.t) { |g| link_to(:EDIT.t, edit_visual_group_path(g)) }
      table.column(:DESTROY.t) { |g| render_destroy_link(g) }
    end

    def render_top_nav
      p do
        [
          link_to(:visual_group_create.t,
                  new_visual_model_visual_group_path(@visual_model)),
          link_to(:edit_object.t(type: :VISUAL_MODEL),
                  edit_visual_model_path(@visual_model)),
          link_to(:show_visual_model_index.t, visual_models_path)
        ].each_with_index do |link, i|
          plain(" | ") if i.positive?
          trusted_html(link)
        end
      end
    end

    def render_destroy_link(group)
      render(Components::Button::Delete.new(
               target: visual_group_path(group),
               variant: :outline
             ))
    end

    def groups
      @visual_groups
    end

    def included_counts
      @included_counts ||= @visual_model.image_counts(true)
    end

    def excluded_counts
      @excluded_counts ||= @visual_model.image_counts(false)
    end

    def count_in(counts, group)
      (counts[group.id] || 0).to_s
    end
  end
end
