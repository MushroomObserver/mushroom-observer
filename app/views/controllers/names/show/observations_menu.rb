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
    render(Components::IconLink.new(tab: tracker_tab))
  end

  def tracker_tab
    if NameTracker.find_by(name_id: @name.id, user_id: @user&.id)
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
    div(class: "col-sm-6 name-section") do
      p { plain(:show_observations_of.t) }
      div(class: "pl-3") { render_obs_link_rows }
      div(class: "py-3") do
        p { render_tab_link(Tab::Name::OccurrenceMap.new(name: @name)) }
      end
    end
  end

  # 5 standard obs-link rows + optional subtaxa-obs row. Each row
  # renders as either `<p><a>label</a> (N)</p>` (count > 0) or
  # `<p>label (0)</p>` (count == 0).
  def render_obs_link_rows
    obs_link_tabs.each { |tab| render_obs_row(tab) }
    render_obs_row(subtaxa_obs_tab) if @has_subtaxa.positive?
  end

  OBS_LINK_TAB_SPECS = [
    [Tab::Name::ObsLink::ThisName, :of_taxon_this_name],
    [Tab::Name::ObsLink::OtherNames, :of_taxon_other_names],
    [Tab::Name::ObsLink::AnyName, :of_taxon_any_name],
    [Tab::Name::ObsLink::TaxonProposed, :where_taxon_proposed],
    [Tab::Name::ObsLink::NameProposed, :where_name_proposed]
  ].freeze
  private_constant :OBS_LINK_TAB_SPECS

  def obs_link_tabs
    OBS_LINK_TAB_SPECS.map do |klass, count_method|
      klass.new(name: @name, count: @obss.send(count_method).size,
                controller: controller)
    end
  end

  def subtaxa_obs_tab
    Tab::Name::ObsLink::Subtaxa.new(
      name: @name, count: @has_subtaxa, query: @subtaxa_query,
      controller: controller
    )
  end

  # Linked → `<p><a>label</a> (N)</p>` with data-attrs from the
  # tab's `#html_options`. Unlinked → plain `<p>label (0)</p>`.
  def render_obs_row(tab)
    p do
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
    plain(" #{count}") if count
  end

  # Tab#title is `"label (N)"`; split into the link text + the
  # trailing "(N)" plain-text suffix.
  def split_title_and_count(title)
    if title =~ /\A(.+?) (\(\d+\))\z/
      [Regexp.last_match(1), Regexp.last_match(2)]
    else
      [title, nil]
    end
  end

  def link_attrs(opts)
    opts.slice(:class, :data, :target, :rel)
  end

  def render_research_links_column
    div(class: "col-sm-6 name-section") do
      p { plain("#{:research_links.l}:") }
      div(class: "pl-3") { render_research_links }
    end
  end

  def render_research_links
    research_link_tabs.each do |tab|
      p { render_tab_link(tab) }
    end
  end

  def research_link_tabs
    [
      ascomycota_tab,
      eol_tab,
      Tab::Name::Gbif.new(name: @name),
      Tab::Name::UserGoogleImages.new(name: @name, user: @user),
      Tab::Name::GoogleSearch.new(name: @name),
      Tab::Name::Inat.new(name: @name),
      *registry_tabs,
      Tab::Name::NcbiNucleotide.new(name: @name),
      Tab::Name::Wikipedia.new(name: @name)
    ].compact
  end

  def ascomycota_tab
    return nil unless @name.classification&.match?(/Phylum: _Ascomycota_/)

    Tab::Name::AscomyceteOrg.new(name: @name)
  end

  def eol_tab
    return nil unless @name.eol_url

    Tab::Name::Eol.new(name: @name)
  end

  def registry_tabs
    return [] unless @name.searchable_in_registry?

    [
      Tab::Name::MushroomExpert.new(name: @name),
      Tab::Name::Mycoportal.new(name: @name)
    ]
  end

  # Render a Tab PORO as an `<a>` link. `Tab::Base#to_a` returns
  # `[text, url, html_options]`.
  def render_tab_link(tab)
    text, url, opts = tab.to_a
    a(href: url, **link_attrs(opts)) { plain(text) }
  end
end
