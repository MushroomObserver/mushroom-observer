# frozen_string_literal: true

# "About this taxon" panel — two-column layout: left column lists
# observation-counting links from `NamesHelper` (the
# `name_related_taxa_observation_links` chain)
# (plus subtaxa observations and the occurrence map link); right column
# lists research-site links built from Tab::Name::* POROs.
#
# `name_related_taxa_observation_links` and its 5-deep chain stay in
# `NamesHelper` — a follow-up PR can move them into a Phlex view
# (`Show::ObservationsMenu::RelatedTaxaLinks`?) when we're ready to
# Phlexify NamesHelper. For now it's a registered helper.
class Views::Controllers::Names::Show::ObservationsMenu < Views::Base
  register_value_helper :name_related_taxa_observation_links

  prop :name, ::Name
  # `Name::Observations` PORO — duck-typed via the methods
  # `NamesHelper#name_related_taxa_observation_links` invokes
  # (`of_taxon_this_name`, `of_taxon_other_names`, etc.).
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

  # Existing tracker → edit; otherwise the "new tracker" tab.
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
      div(class: "pl-3") do
        trusted_html(name_related_taxa_observation_links(@name, @obss))
        render_subtaxa_link if @has_subtaxa
      end
      div(class: "py-3") do
        p { render_tab_link(Tab::Name::OccurrenceMap.new(name: @name)) }
      end
    end
  end

  def render_subtaxa_link
    p do
      a(href: add_q_param(observations_path, @subtaxa_query)) do
        plain(:show_subtaxa_obss.l)
      end
      plain(" (#{@has_subtaxa})")
    end
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
    a(href: url, **(opts || {}).slice(:class, :target, :rel)) do
      plain(text)
    end
  end
end
