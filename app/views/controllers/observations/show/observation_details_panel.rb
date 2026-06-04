# frozen_string_literal: true

# "Observation details" panel — when / where / who, optional GPS,
# specimen-available line, free-text notes, projects list, field
# slip, collection-numbers / herbarium-records / sequences sub-
# panels, and external links. The center column of the obs show
# page (and also rendered into the naming form pages).
#
# Replaces `_observation_details.erb`. Inlines six helpers that
# this partial was the only/primary caller of:
#
# - `obs_details_links` (and its `print_labels_button` dependency)
#   — the "print labels" heading-link
# - `observation_details_when_where_who` + 4 sub-helpers
#   (`observation_details_when` / `_where` / `_where_gps` /
#   `_who`)
# - `observation_where_vague_notice`
# - `observation_details_notes`
#
# The collection_numbers / herbarium_records / sequences /
# external_links sub-panels are still rendered via Phlex views in
# this same directory; the `sibling_*` helpers (read-only
# aggregated records from sibling observations in an occurrence)
# continue to live in `Observations::SiblingRecordsHelper` for now
# — they're called from a partial we haven't converted yet
# (`_observation_details.erb` was the only obs-show caller; once
# the sibling-records-helper callers all go to Phlex, the helpers
# themselves can be inlined into their respective sub-panels).
module Views::Controllers::Observations::Show
  class ObservationDetailsPanel < Views::Base
    include SiblingRecords

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

    # Inlined from `Tabs::ObservationsHelper#obs_details_links` +
    # `print_labels_button` (the only caller of either, here in
    # the heading-link slot).
    def print_labels_button
      name = :download_observations_print_labels.l
      query = ::Query.lookup(::Observation, id_in_set: [@obs.id])
      path = add_q_param(observations_downloads_path(commit: name), query)
      render(Components::CrudButton::Post.new(
               name: name, target: path, icon: :print,
               class: "print_label_observation_#{@obs.id}",
               form: { data: { turbo: false } }
             ))
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
        plain("#{:WHEN.t}: ")
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
        trusted_html(
          location_link(@obs.where, @obs.location, nil, true)
        )
      else
        plain(@obs.where)
      end
    end

    # Inlined from `ObservationsHelper#observation_where_vague_notice`.
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
          [@obs.display_lat_lng.t, @obs.display_alt.t,
           "[#{:click_for_map.t}]"].join(" ")
        )
      end
    end

    def render_gps_hidden_msg
      i { plain("(#{:show_observation_gps_hidden.t})") }
    end

    def render_who
      p(class: "obs-who", id: "observation_who") do
        plain("#{:WHO.t}: ")
        render_who_name
        render_send_question_link if show_send_question?
      end
    end

    def render_who_name
      if @user
        trusted_html(user_link(@obs.user))
      else
        plain(@obs.user.unique_text_name)
      end
    end

    def show_send_question?
      @user && @obs.user != @user &&
        !@obs.user&.no_emails && @obs.user&.email_general_question
    end

    def render_send_question_link
      plain(" [")
      name, path, opts = ::Tab::Observation::SendQuestion.new(
        observation: @obs
      ).to_a
      render(Components::ModalLink.new(
               "observation_email", name, path, **opts
             ))
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

    # Inlined from `ObservationsHelper#observation_details_notes`.
    # Per the helper's preserved comment: passes each notes value
    # to textile independently rather than the whole block — a
    # `+photo` value at the start of a line would otherwise be
    # interpreted as textile bold-emphasis across subsequent lines.
    def render_notes
      notes = @obs.notes
      return if notes == ::Observation.no_notes

      if notes.keys == [:Other]
        trusted_html("#{:NOTES.t}:\n#{notes[:Other]}".tpl)
      else
        render_structured_notes(notes)
      end
    end

    def render_structured_notes(notes)
      div(class: "obs-notes textile", id: "observation_notes") do
        ::Textile.clear_textile_cache
        ::Textile.register_name(@obs.name)
        trusted_html("<p>#{:NOTES.t}:<br>".t)
        notes.each do |key, value|
          trusted_html("+#{key.to_s.tr("_", " ")}+: #{value}<br>".tl)
        end
        trusted_html("</p>".t)
      end
    end

    def render_projects
      div(class: "obs-projects", id: "observation_projects") do
        span { plain("#{:PROJECTS.t}:") }
        br
        @obs.projects.each do |project|
          div(class: "indent") { trusted_html(link_to_object(project)) }
        end
      end
    end

    def render_field_slip
      div(class: "obs-field-slips", id: "observation_field_slips") do
        span { plain("#{:FIELD_SLIP.t}: ") }
        trusted_html(link_to_object(@obs.field_slip))
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
      render(CollectionNumbersPanel.new(
               obs: @obs, user: @user,
               has_sibling_records: sibling_has?(:collection_numbers)
             ))
      render_sibling_records(:collection_numbers) do |cn, sib|
        a(href: collection_number_path(cn.id)) do
          trusted_html(cn.format_name)
        end
        plain(" ")
        sibling_attribution(sib)
      end
    end

    def render_herbarium_records
      render(HerbariumRecordsPanel.new(
               obs: @obs, user: @user,
               has_sibling_records: sibling_has?(:herbarium_records)
             ))
      render_sibling_records(:herbarium_records) do |hr, sib|
        render_sibling_herbarium_record(hr, sib)
      end
    end

    def render_sequences
      render(SequencesPanel.new(
               obs: @obs, user: @user,
               has_sibling_records: sibling_has?(:sequences)
             ))
      render_sibling_records(:sequences) do |seq, sib|
        a(href: sequence_path(seq.id)) { trusted_html(seq.format_name) }
        render_sibling_sequence_archive(seq) if seq.deposit?
        plain(" ")
        sibling_attribution(sib)
      end
    end

    def show_external_links?
      @obs.external_links.any? || @sites.present? ||
        sibling_has?(:external_links)
    end

    def render_external_links_panel
      render(ExternalLinksPanel.new(
               obs: @obs, user: @user, sites: @sites, siblings: @siblings
             ))
    end

    def sibling_has?(association)
      @siblings.any? { |s| s.send(association).any? }
    end
  end
end
