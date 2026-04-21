# frozen_string_literal: true

module Components
  module Checklist
    # Summary + panels for the checklist page. Wraps everything in
    # #checklist_contents so the target-names turbo-stream can replace
    # the whole block when a target is added or removed.
    class Contents < Components::Base
      register_output_helper :location_link, mark_safe: true

      def initialize(data:, context:)
        super()
        @data = data
        @context = context
      end

      def view_template
        div(id: "checklist_contents") do
          render_summary
          render_location_header if @context.location
          render_panels
          render_footnotes
        end
      end

      private

      def for_project?
        @data.is_a?(::Checklist::ForProject)
      end

      def render_summary
        div(class: "my-4") do
          render_target_summary if project_with_targets?
          render_observed_summary
        end
      end

      def project_with_targets?
        for_project? && @data.num_targets.positive?
      end

      def render_target_summary
        div do
          plain(
            :checklist_target_summary.t(
              total: @data.num_targets,
              observed: @data.num_targets_observed,
              unobserved: @data.num_targets_unobserved
            )
          )
        end
      end

      def render_observed_summary
        higher = @data.num_higher_level_observed
        div do
          plain(
            :checklist_observed_summary.t(
              species: @data.num_species_observed,
              higher: higher,
              taxa_word: higher == 1 ? :checklist_taxon.l : :checklist_taxa.l
            )
          )
        end
      end

      def render_location_header
        h4 do
          plain("#{:checklist_for.t} ")
          location_link(nil, @context.location)
        end
      end

      def render_panels
        if for_project?
          render_panel_section(:checklist_unobserved_targets,
                               @data.unobserved_target_taxa,
                               "checklist_unobserved_panel",
                               link_to_name_page: true)
        end
        render_panel_section(:checklist_species_level,
                             @data.species_level_observed_taxa,
                             "checklist_species_panel")
        render_panel_section(:checklist_higher_level,
                             @data.higher_level_observed_taxa,
                             "checklist_higher_panel")
      end

      def render_panel_section(title_key, taxa, panel_id,
                               link_to_name_page: false)
        return if taxa.empty?

        h4 { plain(title_key.t) }
        render(Components::Checklist::Panel.new(
                 data: @data, context: @context,
                 taxa: taxa, panel_id: panel_id,
                 link_to_name_page: link_to_name_page
               ))
      end

      def render_footnotes
        div do
          p { plain(:checklist_any_deprecated.l) } if @data.any_deprecated?
          if @data.duplicate_synonyms.present?
            p { plain(:checklist_duplicate_synonyms.l) }
          end
          render_target_remove_footnote if show_target_remove_footnote?
        end
      end

      def show_target_remove_footnote?
        project_with_targets? && @context.admin?
      end

      def render_target_remove_footnote
        p do
          span(class: "glyphicon glyphicon-remove text-danger")
          plain(" #{:checklist_target_remove_footnote.l}")
        end
      end
    end
  end
end
