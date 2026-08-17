# frozen_string_literal: true

# Turbo Frame body for the observation show page's "About this Taxon"
# panel (#5093) -- the response `Observations::NameInfoPanelsController
# #show` renders when the panel's collapse toggle fetches it. Two
# columns: "On MO" (related-name links + alt-descriptions list +
# distribution map) and "On the web" (external taxonomic search sites
# the user has enabled). Content moved here, unchanged, from the
# formerly-eager `Views::Controllers::Observations::Show::NameInfoPanel`.
module Views::Controllers::Observations::NameInfoPanels
  class Show < Views::Base
    prop :obs, ::Observation
    prop :user, _Nilable(::User), default: nil

    # `target: "_top"` -- links rendered inside a `<turbo-frame>` are
    # frame-scoped by default, so without it, clicking e.g. "About
    # <name>" would try to swap the Names page's content into this
    # small panel frame instead of navigating there.
    def view_template
      turbo_frame_tag(frame_id, target: "_top") { render_body }
    end

    private

    # Must match the placeholder frame id in `Views::Controllers::
    # Observations::Show::NameInfoPanel#render_frame`.
    def frame_id = "name_info_frame_#{@obs.id}"

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
end
