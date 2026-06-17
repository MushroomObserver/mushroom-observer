# frozen_string_literal: true

# Notes panel on the Name show page — rendered when the name has any
# notes. Heading + textile-rendered notes body + edit-icon link for
# logged-in users.
class Views::Controllers::Names::Show::NotesPanel < Views::Base
  prop :name, ::Name
  prop :user, _Nilable(::User), default: nil

  def view_template
    render(Components::Panel.new(panel_id: "name_notes")) do |panel|
      panel.with_heading { plain(:show_name_notes.l) }
      panel.with_heading_links { render_edit_link } if @user
      panel.with_body { trusted_html(@name.notes.tpl) }
    end
  end

  private

  def render_edit_link
    render(Components::Link::Icon.new(
             tab: Tab::Name::Edit.new(name: @name)
           ))
  end
end
