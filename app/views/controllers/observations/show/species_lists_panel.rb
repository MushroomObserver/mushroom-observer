# frozen_string_literal: true

# "Species lists" panel on the observation show page. Heading
# carries a "manage lists" icon-link for users who own any species
# lists. Body lists every species_list this observation is part of,
# with an inline `[REMOVE]` button for any list the user has
# permission to edit.
#
# Replaces `_species_lists.erb`.
class Views::Controllers::Observations::Show::SpeciesListsPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    render(Components::Panel.new(
             panel_id: "observation_species_lists"
           )) do |panel|
      panel.with_heading { :show_lists_header.t }
      panel.with_heading_links { manage_link } if manage_link?
      panel.with_body { render_list } if @obs.species_lists.any?
    end
  end

  private

  def manage_link?
    @user&.species_list_ids&.any?
  end

  def manage_link
    render(Components::Link::Icon.new(
             tab: ::Tab::Observation::ManageLists.new(
               observation: @obs, q_param: q_param
             )
           ))
  end

  def render_list
    ul(class: "list-unstyled mb-0") do
      @obs.species_lists.each { |spl| render_item(spl) }
    end
  end

  def render_item(spl)
    li(id: "species_list_#{spl.id}") do
      a(href: species_list_path(spl.id)) { trusted_html(spl.format_name.t) }
      render_remove_button(spl) if permission?(spl)
    end
  end

  def render_remove_button(spl)
    remove_path = observation_species_list_path(
      id: @obs.id, species_list_id: spl.id, commit: "remove"
    )
    render(Components::CrudButton::Put.new(
             name: "[#{:REMOVE.t}]",
             target: remove_path,
             data: { confirm: :are_you_sure.l }
           ))
  end
end
