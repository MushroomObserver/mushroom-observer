# frozen_string_literal: true

module Views::Controllers::Checklists
  # Renders a single checklist panel: a <ul> of name links wrapped in
  # the shared Panel component. Used by the Contents component for
  # each section (unobserved / species-level / higher-level / default).
  #
  # Every taxon row, its display content, link path, and the optional
  # "remove target name" button live here as private methods.
  class Panel < ::Components::Base
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
        # `::Components::Panel` is the shared building-block panel
        # component — distinct from this view-side `Panel`.
        render(::Components::Panel.new(panel_class: "checklist")) do |panel|
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
      name, name_id, deprecated, synonym_id = taxon
      li_class = target_name?(name_id) ? "checklist-target-name" : nil
      li(class: li_class) do
        link_to(taxon_link_path(name_id)) do
          render_taxon_content(name, deprecated, synonym_id)
        end
        render_taxon_remove_button(name_id)
      end
    end

    def render_taxon_content(name, deprecated, synonym_id)
      i { plain(name) }
      plain(" (#{@data.counts[name]})")
      plain(" *") if deprecated
      plain(" +") if @data.duplicate_synonyms&.include?(synonym_id)
    end

    def taxon_link_path(name_id)
      return name_path(name_id) if @link_to_name_page

      user, project, location, list = @context.link_params
      prefix = link_prefix_for(user:, project:, list:)
      prefix += " location:#{location.id}" if prefix && location
      return name_path(name_id) unless prefix

      observations_path(pattern: "#{prefix} name:#{name_id} " \
                                 "include_synonyms:false " \
                                 "include_subtaxa:false")
    end

    def link_prefix_for(user:, project:, list:)
      return "user:#{user.id}"       if user
      return "project:#{project.id}" if project

      "list:#{list.id}" if list
    end

    def target_name?(name_id)
      @data.respond_to?(:target_name_ids) &&
        @data.target_name_ids.include?(name_id)
    end

    def render_taxon_remove_button(name_id)
      return unless @context.admin?
      return unless @context.project.target_name_ids.include?(name_id)

      render(Components::Button::Delete.new(
               name: :REMOVE.l,
               target: project_target_name_path(
                 project_id: @context.project.id, id: name_id
               ),
               confirm: :project_target_name_confirm_remove.t(
                 name: Name.safe_find(name_id)&.text_name
               ),
               icon: :x,
               variant: :btn_link,
               class: "p-0 ml-1"
             ))
    end
  end
end
