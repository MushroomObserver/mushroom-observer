# frozen_string_literal: true

# "Species lists" panel on the observation show page. When the
# observation already belongs to species lists, the heading is the
# bare "Observation Lists" title with an icon-only "manage lists"
# link flush right (for users who can edit any species list), and the
# body lists every species_list this observation is part of, with
# an inline `[REMOVE]` button for any list the user has permission
# to edit. When the observation belongs to no lists yet, the whole
# heading is an icon+text "Add to an Observation List" link — shown
# only if the user can edit a list to add it to; otherwise the panel
# does not render.
#
# The link is gated on editable lists, not owned ones, so a foray
# recorder who can edit a project list (but owns none) can still add.
#
class Views::Controllers::Observations::Show::SpeciesListsPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    return unless render_panel?

    Panel(panel_id: "observation_species_lists") do |panel|
      if @obs.species_lists.any?
        panel.with_heading { plain(:show_lists_header.t) }
        panel.with_heading_links { manage_link } if manage_link?
        panel.with_body { render_list }
      else
        panel.with_heading { add_to_list_link }
      end
    end
  end

  private

  def render_panel?
    @obs.species_lists.any? || manage_link?
  end

  def manage_link?
    @user&.all_editable_species_lists&.any?
  end

  def manage_link
    Link(type: :get,
         tab: ::Tab::Observation::ManageLists.new(
           observation: @obs, q_param: q_param
         ))
  end

  def add_to_list_link
    Link(type: :get,
         tab: ::Tab::Observation::AddToSpeciesList.new(
           observation: @obs, q_param: q_param
         ),
         label: true)
  end

  def render_list
    ul(class: "list-unstyled mb-0") do
      @obs.species_lists.each { |spl| render_item(spl) }
    end
  end

  def render_item(spl)
    li(id: "species_list_#{spl.id}") do
      a(href: species_list_path(spl.id)) { trusted_html(spl.format_name.t) }
      if permission?(spl)
        whitespace
        render_remove_button(spl)
      end
    end
  end

  def render_remove_button(spl)
    remove_path = observation_species_list_path(
      id: @obs.id, species_list_id: spl.id, commit: "remove"
    )
    Button(
      type: :put,
      variant: :strip,
      icon: :remove,
      icon_class: "text-danger",
      name: :remove.ti,
      target: remove_path,
      confirm: :are_you_sure.l
    )
  end
end
