# frozen_string_literal: true

# "Observation details" panel — when / where / who, optional GPS,
# projects list, field slip, and external links. The center column
# of the obs show page (and also rendered into the naming form
# pages). Specimen-available status + collection-numbers /
# herbarium-records / sequences live in the separate `SpecimenPanel`,
# rendered right below this one.
class Views::Controllers::Observations::Show::ObservationDetailsPanel < Views::Base
  prop :obs, ::Observation
  prop :consensus, _Nilable(::Observation::NamingConsensus), default: nil
  prop :user, _Nilable(::User), default: nil
  prop :sites, _Nilable(_Array(::ExternalSite)), default: nil
  prop :siblings, _Array(::Observation), default: -> { [] }

  def view_template
    Panel(panel_id: "observation_details") do |panel|
      panel.with_heading { :show_observation_details.l }
      panel.with_heading_links { print_labels_button } if @user
      panel.with_body { render_body }
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
    ul(class: "list-unstyled") { render_when_where_who }
    render_projects if @user && @obs.projects.present?
    render_field_slip if @user && @obs.field_slip
    render_external_links_panel if @user && show_external_links?
  end

  # ---- when / where / who -----------------------------------

  def render_when_where_who
    render_when
    render_where
    render_where_gps
    render_who
  end

  def render_when
    li(class: "obs-when", id: "observation_when") do
      plain("#{:WHEN.t}: ")
      b { @obs.when.web_date }
    end
  end

  def render_where
    li(class: "obs-where", id: "observation_where") do
      plain("#{where_label}: ")
      render_where_link
      render_vague_notice
    end
  end

  def where_label
    if @obs.is_collection_location
      :show_observation_collection_location.t
    else
      :show_observation_seen_at.t
    end
  end

  def render_where_link
    if @user
      Link(type: :location,
           where: @obs.where, location: @obs.location, click: true)
    else
      plain(@obs.where)
    end
  end

  def render_vague_notice
    return unless @obs.location&.vague?

    title = :show_observation_vague_location.l.dup
    title << " #{:show_observation_improve_location.l}" if @user == @obs.user
    p(class: "ml-3") { em { plain(title) } }
  end

  def render_where_gps
    return unless @obs.lat && @user

    li(class: "obs-where-gps", id: "observation_where_gps") do
      # XXX Consider dropping this from indexes.
      render_gps_display_link if @obs.reveal_location?(@user)
      render_gps_hidden_msg if @obs.gps_hidden
    end
  end

  def render_gps_display_link
    a(href: map_observation_path(id: @obs.id)) do
      trusted_html(
        [@obs.display_lat_lng.t, @obs.display_alt.t,
         "[#{:click_for_map.t}]"].join(" ")
      )
    end
  end

  def render_gps_hidden_msg
    i { plain("(#{:show_observation_gps_hidden.t})") }
  end

  # "Collector:" and (when they differ) "Entered by:" lines. A field-slip
  # obs with no recorded collector shows only "Entered by:" — we don't
  # claim the entering recorder as the collector. See #4211.
  def render_who
    li(class: "obs-who", id: "observation_who") do
      if @obs.collector_unrecorded?
        render_entered_by
      else
        render_collector
        if @obs.collector_differs_from_creator?
          br
          render_entered_by
        end
      end
    end
  end

  # The send-question link rides the "Collector:" line only when the
  # collector is the entering user; when they differ it moves to the
  # "Entered by:" line (you email the MO account, not a free-text name).
  def render_collector
    plain("#{:COLLECTOR.t}: ")
    render_collector_identity
    return if @obs.collector_differs_from_creator?

    render_send_question_link if show_send_question?
  end

  def render_entered_by
    plain("#{:ENTERED_BY.t}: ")
    render_user_link(@obs.user)
    render_send_question_link if show_send_question?
  end

  # Linked MO user when known, else the free-text collector string, else
  # the entering user.
  def render_collector_identity
    if @obs.collector_user
      render_user_link(@obs.collector_user)
    elsif @obs.collector.present?
      plain(@obs.collector)
    else
      render_user_link(@obs.user)
    end
  end

  def render_user_link(target)
    if @user
      Link(type: :user, user: target)
    else
      plain(target.unique_text_name)
    end
  end

  def show_send_question?
    @user && @obs.user != @user &&
      !@obs.user&.no_emails && @obs.user&.email_general_question
  end

  def render_send_question_link
    InlineLinkBlock(items: [send_question_button])
  end

  def send_question_button
    Components::Button.new(
      type: :modal,
      name: :show_observation_send_question.l,
      target: new_question_for_observation_path(@obs.id),
      modal_id: "observation_email",
      variant: :strip, icon: :email,
      class: Components::InlineLinkBlock.item_class
    )
  end

  # ---- projects / field slip -----------------------------------

  def render_projects
    div(class: "obs-projects", id: "observation_projects") do
      span { plain("#{:PROJECTS.t}:") }
      br
      @obs.projects.each do |project|
        div(class: "indent") do
          Link(type: :object, object: project)
        end
      end
    end
  end

  def render_field_slip
    div(class: "obs-field-slips", id: "observation_field_slips") do
      span { plain("#{:FIELD_SLIP.t}: ") }
      Link(type: :object, object: @obs.field_slip)
    end
  end

  # ---- external links -----------------------------------------

  def show_external_links?
    @obs.external_links.any? || @sites.present? ||
      sibling_has?(:external_links)
  end

  def render_external_links_panel
    render(Views::Controllers::Observations::Show::ExternalLinksPanel.new(
             obs: @obs, user: @user, sites: @sites, siblings: @siblings
           ))
  end

  def sibling_has?(association)
    @siblings.any? { |s| s.send(association).any? }
  end
end
