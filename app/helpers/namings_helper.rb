# frozen_string_literal: true

# helpers for namings view
# TODO: some of this should be in a presenter
module NamingsHelper
  ##### Observation Naming "table" content #########
  def observation_naming_header_row(logged_in)
    heading_html = content_tag(:h4, :show_namings_proposed_names.t,
                               class: "panel-title")
    user_heading_html = content_tag(:small, :show_namings_user.t)
    consensus_heading_html = content_tag(:small, :show_namings_consensus.t)
    your_heading_html = content_tag(:small, :show_namings_your_vote.t)

    {
      heading: heading_html,
      user_name: user_heading_html,
      consensus_vote: consensus_heading_html,
      your_vote: logged_in ? your_heading_html : ""
    }
  end

  def observation_naming_row(observation, naming, vote, logged_in)
    {
      name: naming_name_html(naming),
      proposer: naming_proposer_html(naming),
      consensus_vote: consensus_vote_html(naming),
      your_vote: logged_in ? your_vote_html(naming, vote) : "",
      eyes: vote_icons_html(observation, naming),
      reasons: reasons_html(naming)
    }
  end

  def observation_naming_buttons(observation, do_suggestions)
    buttons = []
    buttons << propose_naming_link(observation.id,
                                   text: :show_namings_propose_new_name.t,
                                   btn_class: "btn-default btn-sm",
                                   context: "namings_table")
    if do_suggestions
      localizations = {
        processing_images: :suggestions_processing_images.t,
        processing_image: :suggestions_processing_image.t,
        processing_results: :suggestions_processing_results.t,
        error: :suggestions_error.t
      }.to_json
      results_url = add_query_param(
        naming_suggestions_for_observation_path(id: observation.id, names: :xxx)
      )
      buttons << button_tag(:show_namings_suggest_names.l,
                            type: :button, class: "btn btn-default btn-sm mt-2",
                            data: { role: "suggest_names",
                                    results_url: results_url,
                                    localization: localizations,
                                    image_ids: observation.image_ids.to_json,
                                    controller: "suggestions",
                                    action: "suggestions#suggestTaxa" })
    end
    buttons.safe_join(tag.br)
  end

  def propose_naming_link(id, text: :create_naming.t, context: "namings_table",
                          btn_class: "btn-primary my-3")
    modal_link_to(
      "naming",
      *new_naming_tab(id, text: text, btn_class: btn_class, context: context)
    )
  end

  private

  def naming_name_html(naming)
    Textile.register_name(naming.name)

    if check_permission(naming)
      edit_link = edit_button(name: :EDIT.t, target: naming,
                              remote: true, onclick: "MOEvents.whirly();")
      delete_link = destroy_button(target: naming, remote: true)
      proposer_links = tag.span(class: "small text-nowrap") do
        ["[", edit_link, " | ", delete_link, "]"].safe_join
      end
    else
      proposer_links = ""
    end

    [naming_name_link(naming), " ", proposer_links].safe_join
  end

  def naming_name_link(naming)
    link_with_query(
      naming.display_name_brief_authors.t.break_name.small_author,
      name_path(id: naming.name)
    )
  end

  def naming_proposer_html(naming)
    user_link = user_link(naming.user, naming.user.login,
                          { class: "btn btn-link px-0" })

    # row props have mobile-friendly labels
    [tag.small("#{:show_namings_user.t}: ", class: "visible-xs-inline mr-4"),
     user_link].safe_join
  end

  def consensus_vote_html(naming)
    consensus_votes =
      (if naming.votes&.length&.positive?
         "#{pct_html(naming)} (#{num_votes_html(naming)})"
       else
         "(#{:show_namings_no_votes.t})"
       end).html_safe # has links

    # row props have mobile-friendly labels
    [tag.small("#{:show_namings_consensus.t}: ",
               class: "visible-xs-inline mr-4"),
     tag.span(consensus_votes)].safe_join
  end

  # Makes a link to naming_vote_path for no-js.
  # The controller will render a modal if js request
  def pct_html(naming)
    percent = "#{naming.vote_percent.round}%"

    link_with_query(h(percent),
                    naming_vote_path(naming_id: naming.id),
                    class: "vote-percent btn btn-link px-0",
                    onclick: "MOEvents.whirly();",
                    remote: true)
  end

  def num_votes_html(naming)
    tag.span(naming.votes&.length,
             class: "vote-number", data: { id: naming.id })
  end

  def your_vote_html(naming, vote)
    # row props have mobile-friendly labels
    [tag.small("#{:show_namings_your_vote.t}: ", class: "visible-xs-block"),
     naming_vote_form(naming, vote, context: "namings_table")].safe_join
  end

  public

  # Naming Vote Form:
  # a tiny form within a naming row for voting on this naming only
  # also called by matrix_box_vote_or_propose_ui
  # Submits via Turbo
  def naming_vote_form(naming, vote, context: "blank")
    menu = Vote.confidence_menu
    can_vote = check_permission(naming)
    menu = [Vote.no_opinion] + menu if !can_vote || !vote || vote&.value&.zero?
    localizations = {
      lose_changes: :show_namings_lose_changes.l.tr("\n", " "),
      saving: :show_namings_saving.l
    }.to_json

    form_with(url: naming_vote_path(naming_id: naming.id), method: :patch,
              turbo: true, id: "naming_vote_#{naming.id}",
              class: "naming-vote-form",
              data: { controller: "naming-vote",
                      localization: localizations }) do |f|
      [
        fields_for(:vote) do |fv|
          fv.select(:value, menu, {},
                    { class: "form-control w-100",
                      data: { role: "change_vote", id: naming.id,
                              naming_vote_target: "select",
                              action: "naming-vote#sendVote" } })
        end,
        hidden_field_tag(:context, context),
        tag.noscript do
          submit_button(form: f, button: :show_namings_cast.l, class: "w-100",
                        data: { role: "save_vote",
                                naming_vote_target: "submit" })
        end
      ].safe_join
    end
  end

  # May show both user and consensus icons
  def vote_icons_html(observation, naming)
    consensus = observation.consensus_naming

    [(observation.owners_favorite?(naming) ? vote_icon_yours : ""),
     (naming == consensus ? vote_icon_consensus : "")].safe_join
  end

  def vote_icon_yours
    tag.div("", class: "vote-icon-width") do
      tag.div("", class: "vote-icon-sizer") do
        tag.div("", class: "vote-icon-yours")
      end
    end
  end

  def vote_icon_consensus
    tag.div("", class: "vote-icon-width") do
      tag.div("", class: "vote-icon-sizer") do
        tag.div("", class: "vote-icon-consensus")
      end
    end
  end

  def vote_legend_yours
    tag.div(class: "d-flex flex-row align-items-center small") do
      [vote_icon_yours, " = ", :show_namings_eye_help.t].safe_join
    end
  end

  def vote_legend_consensus
    tag.div(class: "d-flex flex-row align-items-center small") do
      [vote_icon_consensus, " = ", :show_namings_eyes_help.t].safe_join
    end
  end

  def reasons_html(naming)
    reasons = naming.reasons_array.select(&:used?).map do |reason|
      if reason.notes.blank?
        reason.label.t
      else
        "#{reason.label.l}: #{reason.notes.to_s.html_safe}".tl # may have links
      end
    end

    reasons.map { |reason| content_tag(:div, reason) }.safe_join
  end

  def naming_form_reasons_fields(f_r, reasons)
    reasons.values.sort_by(&:order).map do |rsn|
      tag.div(data: {
                controller: "naming-reason",
                action: "shown.bs.collapse->naming-reason#focusInput"
              }) do
        [
          naming_form_reasons_checkbox(f_r, rsn),
          naming_form_reasons_textarea(f_r, rsn)
        ].safe_join
      end
    end.safe_join
  end

  def naming_form_reasons_checkbox(f_r, rsn)
    tag.div(class: "checkbox") do
      f_r.label("#{rsn.num}_check",
                { data: {
                    toggle: "collapse",
                    target: "#reasons_#{rsn.num}_notes"
                  },
                  aria: {
                    expanded: "false",
                    controls: "reasons_#{rsn.num}_notes"
                  } }) do
        [
          f_r.check_box(:check,
                        { index: rsn.num,
                          checked: rsn.used?,
                          class: "" },
                        "1"),
          rsn.label.t
        ].safe_join
      end
    end
  end

  def naming_form_reasons_textarea(f_r, rsn)
    collapse = rsn.used? ? "" : "collapse"

    tag.div(id: "reasons_#{rsn.num}_notes",
            class: class_names("form-group mb-3", collapse),
            data: { naming_reason_target: "collapse" }) do
      f_r.text_area(
        :notes, index: rsn.num, rows: 3, value: rsn.notes,
                class: "form-control",
                data: { naming_reason_target: "input" }
      )
    end
  end
end
