# frozen_string_literal: true

# "Observation details" panel — an optional external-links "Shared
# with" badge line, when / where / who, optional GPS, and field slip.
# The center column of the obs show page (and also rendered into the
# naming form pages). Specimen-available status + collection-numbers /
# herbarium-records / sequences live in the separate `SpecimenPanel`,
# rendered right below this one. The projects list lives in its own
# `ProjectsPanel`, rendered alongside `SpeciesListsPanel`.
class Views::Controllers::Observations::Show::Details < Views::Base
  prop :obs, ::Observation
  prop :consensus, _Nilable(::Observation::NamingConsensus), default: nil
  prop :user, _Nilable(::User), default: nil
  prop :sites, _Nilable(_Array(::ExternalSite)), default: nil
  prop :siblings, _Array(::Observation), default: -> { [] }

  def view_template
    Panel(panel_id: "observation_details") do |panel|
      panel.with_heading { :show_observation_details.l }
      panel.with_heading_links { print_labels_button } if @user
      with_external_links_body(panel) if show_external_links? && links?
      panel.with_body { render_body }
      with_external_links_body(panel) if show_external_links? && !links?
    end
  end

  private

  def print_labels_button
    name = :download_observations_print_labels.l
    query = ::Query.lookup(::Observation, id_in_set: [@obs.id])
    path = add_q_param(observations_downloads_path(commit: name), query)
    Button(
      type: :post,
      variant: :strip,
      name: name, target: path, icon: :print,
      class: "print_label_observation_#{@obs.id}",
      form: { data: { turbo: false } }
    )
  end

  def render_body
    ul(class: "list-unstyled mb-0") { render_when_where_who }
    render_field_slip if @user && @obs.field_slip
  end

  # ---- when / where / who -----------------------------------

  def render_when_where_who
    ObservationFragment(type: :when, obs: @obs)
    ObservationFragment(type: :where, obs: @obs, user: @user)
    ObservationFragment(type: :where_gps, obs: @obs, user: @user)
    ObservationFragment(type: :who, obs: @obs, user: @user)
  end

  # ---- field slip -----------------------------------------------

  def render_field_slip
    div(class: "obs-field-slips", id: "observation_field_slips") do
      span { plain("#{:field_slip.ti}: ") }
      Link(type: :object, object: @obs.field_slip)
    end
  end

  # ---- external links ---------------------------------------------

  # Matches ExternalLinks' own "hides silently" condition -- a
  # logged-out viewer (or one with no eligible site) gets nothing
  # rendered at all, not an empty .p-0 wrapper with no content.
  def show_external_links?
    links? || (@user && @sites.present?)
  end

  # Own/sibling links to show as badges. Called 3x per render.
  def links?
    return @links if defined?(@links)

    @links = @obs.external_links.any? || sibling_has?(:external_links)
  end

  def with_external_links_body(panel)
    panel.with_body(classes: "p-0", id: "observation_external_links",
                    data: { controller: "section-update",
                            section_update_user_value: @user&.id }) do
      render_external_links_section
    end
  end

  def render_external_links_section
    render(ExternalLinks.new(
             obs: @obs, user: @user, sites: @sites, siblings: @siblings
           ))
  end

  def sibling_has?(association)
    @siblings.any? { |s| s.send(association).any? }
  end
end
