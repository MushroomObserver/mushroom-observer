# frozen_string_literal: true

# "General Description" panel summarizing the name's best description
# in textile-rendered prose. Heading links show / edit description
# when the viewer can edit.
class Views::Controllers::Names::Show::BestDescriptionPanel < Views::Base
  prop :name, ::Name
  # `Name#best_brief_description` returns the textile source as a
  # `String`, not a `Description` record.
  prop :best_description, _Nilable(String)
  prop :user, _Nilable(::User), default: nil

  def view_template
    render(Components::Panel.new(
             panel_id: "name_general_description"
           )) do |panel|
      panel.with_heading { plain(:show_name_general_description.l) }
      panel.with_heading_links { render_heading_links } if @user
      panel.with_body { trusted_html(@best_description.tpl) }
    end
  end

  private

  def render_heading_links
    links = [show_link, edit_link].compact
    links.each_with_index do |link, idx|
      render(link)
      plain(" | ") if idx < links.length - 1
    end
  end

  def show_link
    return nil unless @best_description

    Components::IconLink.new(
      tab: Tab::Name::ShowDescription.new(name: @name)
    )
  end

  def edit_link
    return nil unless @best_description && permission?(@best_description)

    Components::IconLink.new(
      tab: Tab::Name::EditDescription.new(name: @name)
    )
  end
end
