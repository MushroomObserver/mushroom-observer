# frozen_string_literal: true

# "Observation details" panel — when / where / who, optional GPS,
# specimen-available line, free-text notes, projects list, field
# slip, collection-numbers / herbarium-records / sequences sub-
# panels, and external links. The center column of the obs show
# page (and also rendered into the naming form pages).
class Views::Controllers::Observations::Show::ObservationDetailsPanel < Views::Base
  include Views::Controllers::Observations::Show::SiblingRecords

  prop :obs, ::Observation
  prop :consensus, _Nilable(::Observation::NamingConsensus), default: nil
  prop :user, _Nilable(::User), default: nil
  prop :sites, _Nilable(_Array(::ExternalSite)), default: nil
  prop :siblings, _Array(::Observation), default: -> { [] }

  def view_template
    render(Components::Panel.new(
             panel_id: "observation_details",
             panel_class: "name-section"
           )) do |panel|
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
    render_when_where_who
    render_specimen_line if @user
    render_notes
    render_projects if @user && @obs.projects.present?
    render_field_slip if @user && @obs.field_slip
    render_sub_panels_and_external_links if @user
  end

  # ---- when / where / who -----------------------------------

  def render_when_where_who
    render_when
    render_where
    render_where_gps
    render_who
  end

  def render_when
    p(class: "obs-when", id: "observation_when") do
      plain("#{:when.ti}: ")
      b { @obs.when.web_date }
    end
  end

  def render_where
    p(class: "obs-where", id: "observation_where") do
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

    p(class: "obs-where-gps", id: "observation_where_gps") do
      # XXX Consider dropping this from indexes.
      render_gps_display_link if @obs.reveal_location?(@user)
      render_gps_hidden_msg if @obs.gps_hidden
    end
  end

  def render_gps_display_link
    a(href: map_observation_path(id: @obs.id)) do
      trusted_html(
        [display_lat_lng(@obs.lat, @obs.lng).t, display_alt(@obs.alt).t,
         "[#{:click_for_map.t}]"].compact_blank.join(" ")
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
    p(class: "obs-who", id: "observation_who") do
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
    plain("#{:collector.ti}: ")
    render_collector_identity
    return if @obs.collector_differs_from_creator?

    render_send_question_link if show_send_question?
  end

  def render_entered_by
    plain("#{:entered_by.ti}: ")
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
    plain(" [")
    Button(
      type: :modal,
      name: :show_observation_send_question.l,
      target: new_question_for_observation_path(@obs.id),
      modal_id: "observation_email",
      variant: :strip, icon: :email
    )
    plain("]")
  end

  # ---- specimen / notes / projects / field slip --------------

  def render_specimen_line
    p(class: "obs-specimen", id: "observation_specimen_available") do
      if @obs.occurrence&.has_specimen || @obs.specimen
        plain(:show_observation_specimen_available.t)
      else
        plain(:show_observation_specimen_not_available.t)
      end
    end
  end

  # Passes each notes value to textile independently rather than
  # the whole block — a `+photo` value at the start of a line
  # would otherwise be interpreted as textile bold-emphasis across
  # subsequent lines.
  def render_notes
    notes = @obs.notes
    return if notes == ::Observation.no_notes

    div(class: "obs-notes textile", id: "observation_notes") do
      # ApplicationController resets the per-request Textile cache
      # before every action; this only needs to prime it.
      ::Textile.register_name(@obs.name)
      trusted_html("#{:notes.ti}:".t)
      div(class: "indent") { render_note_values(notes) }
    end
  end

  # "Other"-only notes show just the value (MO omits the lone "Other"
  # caption); multi-part notes show each caption with its value indented
  # beneath it. Values render via `.tpl` (full textile) so blank lines
  # survive as paragraph breaks — `.tl` keeps only the first paragraph
  # and would truncate the note at its first blank line (#4536).
  def render_note_values(notes)
    if notes.keys == [:Other]
      trusted_html(notes[:Other].to_s.tpl)
    else
      notes.each { |key, value| render_note_part(key, value) }
    end
  end

  def render_note_part(key, value)
    trusted_html("+#{key.to_s.tr("_", " ")}+:".tl)
    div(class: "indent") { trusted_html(value.to_s.tpl) }
  end

  def render_projects
    div(class: "obs-projects", id: "observation_projects") do
      span { plain("#{:projects.ti}:") }
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
      span { plain("#{:field_slip.ti}: ") }
      Link(type: :object, object: @obs.field_slip)
    end
  end

  # ---- sub-panels (collection / herbarium / sequences / EL) --

  def render_sub_panels_and_external_links
    render_collection_numbers
    render_herbarium_records
    render_sequences
    render_external_links_panel if show_external_links?
  end

  def render_collection_numbers
    render(Views::Controllers::Observations::Show::CollectionNumbersPanel.new(
             obs: @obs, user: @user,
             has_sibling_records: sibling_has?(:collection_numbers)
           ))
    render_sibling_records(:collection_numbers) do |cn, sib|
      a(href: collection_number_path(cn.id)) do
        trusted_html(cn.format_name)
      end
      whitespace
      sibling_attribution(sib)
    end
  end

  def render_herbarium_records
    render(Views::Controllers::Observations::Show::HerbariumRecordsPanel.new(
             obs: @obs, user: @user,
             has_sibling_records: sibling_has?(:herbarium_records)
           ))
    render_sibling_records(:herbarium_records) do |hr, sib|
      render_sibling_herbarium_record(hr, sib)
    end
  end

  def render_sequences
    render(Views::Controllers::Observations::Show::SequencesPanel.new(
             obs: @obs, user: @user,
             has_sibling_records: sibling_has?(:sequences)
           ))
    render_sibling_records(:sequences) do |seq, sib|
      a(href: sequence_path(seq.id)) { trusted_html(seq.format_name) }
      render_sibling_sequence_archive(seq) if seq.deposit?
      whitespace
      sibling_attribution(sib)
    end
  end

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
