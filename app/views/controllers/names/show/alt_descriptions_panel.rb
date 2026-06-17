# frozen_string_literal: true

# "Descriptions" panel on the Name show page. Renders the
# `Views::Controllers::Descriptions::List` inside a `Components::Panel`; the
# panel heading carries a "create new description" icon-link for
# logged-in users. Replaces `_alt_descriptions_panel.html.erb`.
class Views::Controllers::Names::Show::AltDescriptionsPanel < Views::Base
  prop :user, _Nilable(::User), default: nil
  prop :name, ::Name

  def view_template
    render(Components::Panel.new(panel_id: "name_descriptions")) do |panel|
      panel.with_heading { :show_name_descriptions.l }
      panel.with_heading_links { heading_links } if @user
      panel.with_body { render_descriptions_list }
    end
  end

  private

  def heading_links
    render(Components::Link::Icon.new(
             tab: Tab::Name::NewDescription.new(name: @name)
           ))
  end

  def render_descriptions_list
    render(Views::Controllers::Descriptions::List.new(
             user: @user, object: @name, type: :name,
             empty_text: :show_name_no_descriptions.t
           ))
  end
end
