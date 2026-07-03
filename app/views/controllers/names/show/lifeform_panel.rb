# frozen_string_literal: true

# Lifeform panel — lists each `lifeform_*` term from the name's
# space-separated lifeform string, plus a "Propagate lifeform" link
# when this name has subtaxa (`@first_child` is non-nil).
class Views::Controllers::Names::Show::LifeformPanel < Views::Base
  prop :name, ::Name
  prop :first_child, _Nilable(::Name), default: nil
  prop :user, _Nilable(::User), default: nil

  def view_template
    render(Components::Panel.new(
             panel_class: "name-section",
             panel_id: "name_lifeform",
             attributes: { data: { name_panels_target: "lifeform" } }
           )) do |panel|
      panel.with_heading { plain(:show_name_lifeform.l) }
      panel.with_heading_links { render_edit_link } if @user
      panel.with_body { render_body }
    end
  end

  private

  def render_edit_link
    Link(type: :icon, tab: Tab::Name::EditLifeform.new(name: @name))
  end

  def render_body
    render_lifeform_terms if @name.lifeform.present?
    render_propagate_link if @first_child
  end

  def render_lifeform_terms
    div(class: "mb-2") do
      @name.lifeform.strip.split.each do |word|
        p { plain(:"lifeform_#{word}".t) }
      end
    end
  end

  def render_propagate_link
    p do
      a(
        href: form_to_propagate_lifeform_of_name_path(@name.id)
      ) { plain(:show_name_propagate_lifeform.t) }
    end
  end
end
