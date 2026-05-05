# frozen_string_literal: true

module Components
  module Checklist
    # Renders a single checklist panel: a <ul> of name links wrapped in the
    # shared Panel component. Used by the Contents component for each
    # section (unobserved / species-level / higher-level / default).
    class Panel < Components::Base
      register_output_helper :checklist_name_link, mark_safe: true

      def initialize(data:, context:, taxa: nil,
                     panel_id: "checklist_panel",
                     link_to_name_page: false)
        super()
        @data = data
        @context = context
        @taxa = taxa || data.taxa
        @panel_id = panel_id
        @link_to_name_page = link_to_name_page
      end

      def view_template
        div(id: @panel_id) do
          render(Components::Panel.new(panel_class: "checklist")) do |panel|
            panel.with_body do
              ul(class: "list-unstyled") do
                @taxa.each { |taxon| render_taxon(taxon) }
              end
            end
          end
        end
      end

      private

      def render_taxon(taxon)
        checklist_name_link(
          taxon: taxon, data: @data, context: @context,
          link_to_name_page: @link_to_name_page
        )
      end
    end
  end
end
