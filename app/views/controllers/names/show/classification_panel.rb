# frozen_string_literal: true

# Classification panel — shows the approved name + ancestor chain,
# plus action links (refresh, propagate, inherit, subtaxa query) that
# live in `NamesHelper`. Data attrs wire the panel up to the
# `name-panels` Stimulus controller for the side-by-side collapse
# with the lifeform panel.
class Views::Controllers::Names::Show::ClassificationPanel < Views::Base
  register_value_helper :approved_name_and_parents
  register_value_helper :name_subtaxa_query_link
  register_value_helper :refresh_classification_link
  register_value_helper :propagate_classification_link
  register_value_helper :inherit_classification_link

  prop :name, ::Name
  prop :children_query, _Nilable(::Query::Names), default: nil
  prop :first_child, _Nilable(::Name), default: nil
  prop :user, _Nilable(::User), default: nil

  def view_template
    render(Components::Panel.new(
             panel_class: "name-section",
             panel_id: "name_classification",
             attributes: { data: {
               name_panels_target: "classification"
             } }
           )) do |panel|
      panel.with_heading { plain(:show_name_classification.l) }
      panel.with_heading_links { render_edit_link } if @user
      panel.with_body { render_body }
    end
  end

  private

  def render_edit_link
    render(Components::IconLink.new(
             tab: Tab::Name::EditClassification.new(name: @name)
           ))
  end

  def render_body
    trusted_html(approved_name_and_parents(@name))
    if @first_child
      trusted_html(name_subtaxa_query_link(@name, @children_query))
    end
    trusted_html(refresh_classification_link(@name))
    trusted_html(propagate_classification_link(@name)) if @first_child
    trusted_html(inherit_classification_link(@name))
  end
end
