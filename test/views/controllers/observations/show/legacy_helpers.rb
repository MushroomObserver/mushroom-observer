# frozen_string_literal: true

# Legacy helper definitions restored from `main` so the obs/show
# parity tests can render the legacy ERB partials. The originals
# were deleted in this PR (their bodies got inlined into the new
# Phlex panels). The fixtures + this module are deleted together
# once the PR merges and the parity tests have served their
# purpose.
module Views::Controllers::Observations::Show::LegacyHelpers
  # --- ObservationsHelper methods (deleted in this PR) ---

  def observation_show_image_links(obs:)
    return "" unless permission?(obs)

    icon_link_to(*Tab::Observation::ReuseImages.new(observation: obs).to_a)
  end

  def observation_details_when_where_who(obs:, user:)
    [
      observation_details_when(obs:),
      observation_details_where(obs:, user:),
      observation_details_where_gps(obs:, user:),
      observation_details_who(obs:, user:)
    ].safe_join
  end

  def observation_details_when(obs:)
    tag.p(class: "obs-when", id: "observation_when") do
      ["#{:WHEN.t}:", tag.b(obs.when.web_date)].safe_join(" ")
    end
  end

  def observation_details_where(obs:, user:)
    tag.p(class: "obs-where", id: "observation_where") do
      [
        "#{if obs.is_collection_location
             :show_observation_collection_location.t
           else
             :show_observation_seen_at.t
           end}:",
        if user
          location_link(obs.where, obs.location, nil, true)
        else
          obs.where
        end,
        observation_where_vague_notice(obs:, user:)
      ].safe_join(" ")
    end
  end

  def observation_where_vague_notice(obs:, user:)
    return "" unless obs.location&.vague?

    title = :show_observation_vague_location.l
    title += " #{:show_observation_improve_location.l}" if user == obs.user
    tag.p(class: "ml-3") { tag.em(title) }
  end

  def observation_details_where_gps(obs:, user:)
    return "" unless obs.lat && user

    gps_display_link = link_to([obs.display_lat_lng.t,
                                obs.display_alt.t,
                                "[#{:click_for_map.t}]"].safe_join(" "),
                               map_observation_path(id: obs.id))
    gps_hidden_msg = tag.i("(#{:show_observation_gps_hidden.t})")

    tag.p(class: "obs-where-gps", id: "observation_where_gps") do
      # XXX Consider dropping this from indexes.
      concat(gps_display_link) if obs.reveal_location?(user)
      concat(gps_hidden_msg) if obs.gps_hidden
    end
  end

  def observation_details_who(obs:, user:)
    obs_user = obs.user
    html = [
      "#{:WHO.t}:",
      if user
        user_link(obs_user)
      else
        obs_user.unique_text_name
      end
    ]
    if user && obs_user != user && !obs_user&.no_emails &&
       obs_user&.email_general_question

      html += [
        "[",
        modal_link_to(
          "observation_email",
          *Tab::Observation::SendQuestion.new(observation: obs).to_a
        ),
        "]"
      ]
    end

    tag.p(class: "obs-who", id: "observation_who") do
      html.safe_join(" ")
    end
  end

  def observation_details_notes(obs:)
    notes = obs.notes
    return "" if notes == Observation.no_notes
    return "#{:NOTES.t}:\n#{notes[:Other]}".tpl if notes.keys == [:Other]

    # This used to use
    #
    # notes = obs.notes_show_preformatted.sub(/^/, "#{:NOTES.t}:\n").tpl
    #
    # However, this fails if one of the values has a '+' sign, e.g., "+photo"
    # because the textile interpretation ends up affecting multiple lines.
    # This approach passes each note independently to textile.
    tag.div(class: "obs-notes textile", id: "observation_notes") do
      Textile.clear_textile_cache
      Textile.register_name(obs.name)
      concat("<p>#{:NOTES.t}:<br>".t)
      notes.each_with_object(+"") do |(key, value), _str|
        concat("+#{key.to_s.tr("_", " ")}+: #{value}<br>".tl)
      end
      concat("</p>".t)
    end
  end

  def owner_naming_line(name:, owner_name:, user:)
    return unless user&.view_owner_id && owner_name && owner_name.id != name.id

    [
      owner_preferred_naming(user, owner_name).t,
      "(#{:show_observation_owner_id.l})"
    ].safe_join(" ")
  end

  def owner_preferred_naming(user, owner_name)
    link_to_display_name_brief_authors(
      user, owner_name, class: "obs_owner_naming_link_#{owner_name.id}"
    )
  end

  # --- Tabs::ObservationsHelper methods (deleted in this PR) ---

  def name_links_on_mo(user:, name:)
    related = Tab::Observation::RelatedNameTabs.new(
      user: user, name: name
    ).map(&:to_a)
    occ_map = Tab::Name::OccurrenceMap.new(name: name).to_a
    tabs = context_nav_links(related, { class: "d-block" })
    tabs += obs_name_description_tabs(user, name)
    tabs += context_nav_links([occ_map], { class: "d-block" })
    tabs.reject(&:empty?)
  end

  def obs_name_description_tabs(user, name)
    list_descriptions(user: user, object: name, type: :name)&.map do |link|
      tag.div(link)
    end
  end

  def user_name_links_web(user, name:)
    web = Tab::Observation::WebNameTabs.new(
      user: user, name: name
    ).map(&:to_a)
    context_nav_links(web, { class: "d-block" }).reject(&:empty?)
  end

  def obs_details_links(obs)
    print_labels_button(obs)
  end

  def print_labels_button(obs)
    name = :download_observations_print_labels.l
    query = Query.lookup(Observation, id_in_set: [obs.id])
    path = add_q_param(observations_downloads_path(commit: name), query)

    post_button(name: name, path: path, icon: :print,
                class: "print_label_observation_#{obs.id}",
                form: { data: { turbo: false } })
  end

  # --- Observations::SiblingRecordsHelper (whole module, deleted) ---
  def sibling_collection_numbers(siblings)
    sibling_record_list(siblings, :collection_numbers) do |cn, sib|
      [link_to(cn.format_name, collection_number_path(cn.id)),
       sibling_attribution(sib)].safe_join(" ")
    end
  end

  def sibling_herbarium_records(siblings)
    sibling_record_list(siblings, :herbarium_records) do |hr, sib|
      sibling_herbarium_record_content(hr, sib)
    end
  end

  def sibling_sequences(siblings)
    sibling_record_list(siblings, :sequences) do |seq, sib|
      parts = [link_to(seq.format_name, sequence_path(seq.id))]
      parts << sibling_sequence_archive_link(seq) if seq.deposit?
      parts << sibling_attribution(sib)
      parts.safe_join(" ")
    end
  end

  # Returns raw <li> tags (no wrapping <ul>) for integration into
  # the existing external_links partial list.
  def sibling_external_link_items(siblings)
    items = siblings.flat_map do |sib|
      sib.external_links.map { |el| [el, sib] }
    end
    return "".html_safe if items.empty?

    items.map do |el, sib|
      tag.li { sibling_external_link_content(el, sib) }
    end.safe_join
  end

  private

  def sibling_record_list(siblings, association)
    items = siblings.flat_map do |sib|
      sib.send(association).map { |rec| [rec, sib] }
    end
    return if items.empty?

    tag.ul(class: "tight-list") do
      items.map { |rec, sib| tag.li { yield(rec, sib) } }.
        safe_join
    end
  end

  def sibling_sequence_archive_link(seq)
    link = link_to(:show_observation_archive_link.t, seq.accession_url,
                   target: "_blank", rel: "noopener")
    "[".html_safe + link + "]".html_safe
  end

  def sibling_herbarium_record_content(record, sibling)
    parts = [link_to(record.accession_at_herbarium.t,
                     herbarium_record_path(record.id)),
             sibling_attribution(sibling)]
    if record.herbarium.web_searchable?
      parts << tag.br
      parts << mcp_search_link(record)
    end
    parts.safe_join(" ")
  end

  def mcp_search_link(record)
    tag.span(class: "indent") do
      link_to(:herbarium_record_collection.t,
              record.herbarium.mcp_url(record.accession_number),
              target: "_blank", rel: "noopener")
    end
  end

  def sibling_external_link_content(ext_link, sibling)
    link_text = if ext_link.external_site.name == "iNaturalist"
                  inat_label(ext_link)
                else
                  ext_link.site_name
                end
    [link_to(link_text, ext_link.url),
     sibling_attribution(sibling)].safe_join(" ")
  end

  def inat_label(ext_link)
    "iNat #{ext_link.url.sub(ext_link.external_site.base_url, "")}"
  end

  def sibling_attribution(sibling)
    obs_link = link_to("MO #{sibling.id}",
                       permanent_observation_path(sibling.id))
    tag.small("(".html_safe + obs_link + ")".html_safe,
              class: "text-muted")
  end
end
