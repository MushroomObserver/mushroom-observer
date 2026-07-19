# frozen_string_literal: true

# "Species lists" panel on the observation show page. When the
# observation already belongs to species lists, the heading is the
# bare "Observation Lists" title with an icon-only "manage lists"
# link flush right (for users who own any species lists), and the
# body lists every species_list this observation is part of, with
# an inline `[REMOVE]` button for any list the user has permission
# to edit. When the observation belongs to no lists yet, the whole
# heading is an icon+text "Add to an Observation List" link — shown
# only if the user owns a list to add it to; otherwise the panel
# doesn't render at all.
#
class Views::Controllers::Observations::Show::SpeciesListsPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    return unless render_panel?

    render(Components::Panel.new(
             panel_id: "observation_species_lists"
           )) do |panel|
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
    @user&.species_list_ids&.any?
  end

  def manage_link
    Link(type: :icon,
         tab: ::Tab::Observation::ManageLists.new(
           observation: @obs, q_param: q_param
         ))
  end

  def add_to_list_link
    Link(type: :icon,
         tab: ::Tab::Observation::AddToSpeciesList.new(
           observation: @obs, q_param: q_param
         ),
         show_text: true)
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
