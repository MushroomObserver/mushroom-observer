# frozen_string_literal: true

# "About this taxon" panel on the observation show page. Two
# columns: "On MO" (related-name links + alt-descriptions list +
# distribution map) and "On the web" (external taxonomic search
# sites the user has enabled).
class Views::Controllers::Observations::Show::NameInfoPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    Panel(panel_id: "observation_name_info",
          panel_class: "small") do |panel|
      panel.with_heading { :about_this_taxon.l }
      panel.with_body { render_body }
    end
  end

  private

  def render_body
    Row do
      Column(xs: 6) do
        div(class: "font-weight-bold") { plain("#{:on_mo.l}:") }
        render_links_on_mo
      end
      Column(xs: 6) do
        div(class: "font-weight-bold") { plain("#{:on_the_web.l}:") }
        render_links_on_web
      end
    end
  end

  # Three groups, each rendered as a block-level div wrapping the link:
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

  def render_tab_link(tab)
    div do
      if tab.html_options[:external]
        Link(type: :external, tab: tab)
      else
        content, path, opts = tab.to_a
        a(href: url_for(path),
          class: opts[:class]) { trusted_html(content) }
      end
    end
  end
end
