# frozen_string_literal: true

# Classification panel — shows the approved name + ancestor chain,
# plus 4 action links/buttons (subtaxa query, refresh, propagate,
# inherit) each modeled as a Tab PORO so the conditional render
# logic lives on the Tab class (via `.for(name:)` predicates), not
# in the view.
#
# Data attrs wire the panel up to the `name-panels` Stimulus
# controller for the side-by-side collapse with the lifeform panel.
class Views::Controllers::Names::Show::ClassificationPanel < Views::Base
  # `rank_as_string` (LocalizationHelper) maps the integer rank
  # column to its localized label ("Genus", "Family", ...).
  register_value_helper :rank_as_string

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
    render_approved_name_and_parents
    render_subtaxa_query_link if @first_child
    render_action_tab(Tab::Name::RefreshClassification.for(name: @name))
    if @first_child
      render_action_tab(Tab::Name::PropagateClassification.for(name: @name))
    end
    render_action_tab(Tab::Name::InheritClassification.for(name: @name))
  end

  # --- Approved name + parents chain ----------------------------

  # Multi-row content block — stays a private method (not a Tab)
  # because each row is a `<p>` with rank/name and the approved-vs-
  # alias-suffix logic doesn't fit a single-link Tab shape.
  def render_approved_name_and_parents
    approved = @name.approved_name
    parents = approved.all_parents
    return unless approved.classification.present? && parents.any?

    div(class: "mb-2") do
      ([approved] + parents).reverse_each do |n|
        render_classification_row(n, approved)
      end
    end
  end

  def render_classification_row(node, approved)
    p do
      plain("#{rank_as_string(node.rank)}: ")
      i do
        a(href: name_path(node.id)) do
          plain(node.text_name.t.strip_html)
        end
      end
      render_alias_suffix if node == approved && approved != @name
    end
  end

  def render_alias_suffix
    br
    plain("   (= ")
    i { plain(@name.text_name.t.strip_html) }
    plain(")")
  end

  # --- Action links / buttons -----------------------------------

  def render_subtaxa_query_link
    tab = Tab::Name::Subtaxa.new(
      name: @name, children_query: @children_query, controller: controller
    )
    p { render_tab_link(tab) }
  end

  # `.for(name:)` returns nil when the action doesn't apply for
  # this Name's state — skip rendering.
  def render_action_tab(tab)
    return unless tab

    p { render_tab_button_or_link(tab) }
  end

  def render_tab_button_or_link(tab)
    text, url, opts = tab.to_a
    if opts[:button] == :put
      render(Components::CrudButton::Put.new(name: text, target: url))
    else
      a(href: url, **opts.slice(:class, :data, :target, :rel)) do
        plain(text)
      end
    end
  end

  def render_tab_link(tab)
    text, url, opts = tab.to_a
    a(href: url, **opts.slice(:class, :data, :target, :rel)) do
      plain(text)
    end
  end
end
