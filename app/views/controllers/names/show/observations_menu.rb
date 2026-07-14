# frozen_string_literal: true

# "About this taxon" panel — two-column layout: left column lists
# 5 observation-counting links (`Tab::Name::ObsLink::*`) plus the
# subtaxa observations link (`Tab::Name::ObsLink::Subtaxa`) and the
# occurrence-map link; right column lists research-site links built
# from `Tab::Name::*` POROs (Eol, Wikipedia, GBIF, ...).
#
# The 5 obs-counting query-link Tabs each carry their own
# `Query::Observations` build (via `Tab::QueryLink` plumbing), so
# the view doesn't need to know how queries are constructed — it
# just renders the Tab tuples.
class Views::Controllers::Names::Show::ObservationsMenu < Views::Base
  prop :name, ::Name
  # `Name::Observations` PORO — duck-typed via the count-returning
  # methods consumed below.
  prop :obss, _Interface(:of_taxon_this_name)
  prop :subtaxa_query, _Nilable(::Query::Observations), default: nil
  prop :has_subtaxa, Integer, default: 0
  # Whether the current user has a NameTracker on this name. The
  # controller pre-computes this so `tracker_tab` doesn't fire an
  # `exists?` query.
  prop :has_name_tracker, _Boolean
  prop :user, _Nilable(::User), default: nil

  def view_template
    render(Components::Panel.new(
             panel_id: "name_observations_menu"
           )) do |panel|
      panel.with_heading { plain(:about_this_taxon.l) }
      panel.with_heading_links { render_tracker_link }
      panel.with_body { render_body }
    end
  end

  private

  def render_tracker_link
    Link(type: :icon, tab: tracker_tab)
  end

  def tracker_tab
    if @has_name_tracker
      Tab::Name::EditTracker.new(name: @name)
    else
      Tab::Name::NewTracker.new(name: @name)
    end
  end

  def render_body
    div(class: "row") do
      render_observations_column
      render_research_links_column
    end
  end

  def render_observations_column
    Column(xs: 12, sm: 6, class: "name-section") do
      p { plain(:show_observations_of.t) }
      ul(class: "list-unstyled pl-3") { render_obs_link_rows }
      div(class: "py-3") do
        p { render_tab_link(Tab::Name::OccurrenceMap.new(name: @name)) }
      end
    end
  end

  # The `Tab::Name::ObsLink::All` Collection owns the orchestration
  # of "which obs-link tabs to show" (5 standard + optional
  # subtaxa-obs). The view just iterates and renders each `<li>`.
  def render_obs_link_rows
    Tab::Name::ObsLink::All.new(
      name: @name, obss: @obss, controller: controller,
      subtaxa_query: @subtaxa_query, has_subtaxa: @has_subtaxa
    ).each { |tab| render_obs_row(tab) }
  end

  # Linked → `<li><a>label</a> (N)</li>` with data-attrs from the
  # tab's `#html_options`. Unlinked → plain `<li>label (0)</li>`.
  def render_obs_row(tab)
    li do
      if tab.linked?
        render_obs_link(tab)
      else
        plain(tab.title)
      end
    end
  end

  def render_obs_link(tab)
    title, url, opts = tab.to_a
    label, count = split_title_and_count(title)
    a(href: url, **link_attrs(opts)) { plain(label) }
    plain(" #{count}")
  end

  # `Tab::Name::ObsLink#title` is always `"label (N)"` — split into
  # the link text + the trailing "(N)" plain-text suffix.
  def split_title_and_count(title)
    match = title.match(/\A(.+?) (\(\d+\))\z/)
    [match[1], match[2]]
  end

  def link_attrs(opts)
    opts.slice(:class, :data, :target, :rel)
  end

  def render_research_links_column
    Column(xs: 12, sm: 6, class: "name-section") do
      p { plain("#{:research_links.l}:") }
      ul(class: "list-unstyled pl-3") { render_research_links }
    end
  end

  # The `Tab::Name::ResearchLinks` Collection owns the orchestration
  # of which external-site tabs to show (Ascomycete-only, EOL-only,
  # registry-only branches all live there). The view just iterates.
  def render_research_links
    Tab::Name::ResearchLinks.new(name: @name, user: @user).each do |tab|
      li { render_tab_link(tab) }
    end
  end

  # Render a Tab PORO as an `<a>` link. `Tab::Base#to_a` returns
  # `[text, url, html_options]`.
  def render_tab_link(tab)
    text, url, opts = tab.to_a
    a(href: url, **link_attrs(opts)) { plain(text) }
  end
end
