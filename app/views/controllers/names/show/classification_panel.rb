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
    render_link_tabs
  end

  # The `Tab::Name::ClassificationLinks` Collection owns the
  # orchestration: which of the 4 link tabs to show given this
  # Name's state (`first_child` + the visibility predicates on
  # each tab). The view just iterates inside a `<ul>`.
  def render_link_tabs
    ul(class: "list-unstyled") do
      Tab::Name::ClassificationLinks.new(
        name: @name, children_query: @children_query,
        first_child: @first_child, controller: controller
      ).each { |tab| render_link_tab(tab) }
    end
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
          trusted_html(node.text_name.t)
        end
      end
      render_alias_suffix if node == approved && approved != @name
    end
  end

  # Bootstrap left-margin instead of the original helper's `safe_br
  # + safe_nbsp + safe_nbsp` indent — semantic spacing rather than
  # smuggling layout through `&nbsp;` characters.
  def render_alias_suffix
    span(class: "ml-4") do
      plain("(= ")
      i { trusted_html(@name.text_name.t) }
      plain(")")
    end
  end

  # --- Link / button rendering ----------------------------------

  # Each Collection-returned tab renders inside its own `<li>`.
  # PUT-button tabs go through `Components::CrudButton::Put`;
  # plain-link tabs render as `<a>`.
  def render_link_tab(tab)
    li do
      text, url, opts = tab.to_a
      if opts[:button] == :put
        render(Components::CrudButton::Put.new(name: text, target: url))
      else
        a(href: url, **opts.slice(:class, :data, :target, :rel)) do
          plain(text)
        end
      end
    end
  end
end
