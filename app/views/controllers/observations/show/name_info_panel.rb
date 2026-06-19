# frozen_string_literal: true

# "About this taxon" panel on the observation show page. Two
# columns: "On MO" (related-name links + alt-descriptions list +
# distribution map) and "On the web" (external taxonomic search
# sites the user has enabled).
class Views::Controllers::Observations::Show::NameInfoPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    render(Components::Panel.new(
             panel_id: "observation_name_info",
             panel_class: "name-section small"
           )) do |panel|
      panel.with_heading { :about_this_taxon.l }
      panel.with_body { render_body }
    end
  end

  private

  def render_body
    div(class: "row") do
      div(class: "col-xs-6") do
        div(class: "font-weight-bold") { plain("#{:on_mo.l}:") }
        render_links_on_mo
      end
      div(class: "col-xs-6") do
        div(class: "font-weight-bold") { plain("#{:on_the_web.l}:") }
        render_links_on_web
      end
    end
  end

  # Three groups, each emitted as `<a class="d-block">` lines:
  # related-name filtered indexes, alt-descriptions list, and
  # the per-name distribution map link.
  def render_links_on_mo
    related_name_tabs.each { |tab| render_tab_link(tab) }
    render_alt_descriptions
    render_tab_link(occurrence_map_tab)
  end

  def render_links_on_web
    web_name_tabs.each { |tab| render_tab_link(tab) }
  end

  def related_name_tabs
    ::Tab::Observation::RelatedNameTabs.new(
      user: @user, name: @obs.name
    ).reject { |tab| tab.to_a.empty? }
  end

  def web_name_tabs
    ::Tab::Observation::WebNameTabs.new(
      user: @user, name: @obs.name
    ).reject { |tab| tab.to_a.empty? }
  end

  def occurrence_map_tab
    ::Tab::Name::OccurrenceMap.new(name: @obs.name)
  end

  # Renders the alt-description list inline — same view used by
  # the names / locations show pages, just no panel chrome here.
  def render_alt_descriptions
    render(::Views::Controllers::Descriptions::List.new(
             user: @user, object: @obs.name, type: :name
           ))
  end

  # Renders a single Tab::Base as `<a class="d-block">...</a>`.
  # The tabs in this panel are all link-style (no `button:` html_options).
  def render_tab_link(tab)
    content, path, opts = tab.to_a
    classes = ["d-block", opts[:class]].compact.join(" ").strip
    # `:button` is consumed by `context_nav_link` to switch to
    # `button_to`; `:target` is stripped (these tabs aren't the
    # "open in new tab" kind). Match the legacy helper's
    # `merge_context_nav_link_args` filter so attrs line up.
    attrs = opts.except(:class, :button, :target).
            merge(href: url_for(path), class: classes)
    a(**attrs) { trusted_html(content) }
  end
end
