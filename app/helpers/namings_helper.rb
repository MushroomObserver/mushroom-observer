# frozen_string_literal: true

# These helpers generate HTML for the "cells" of the namings "table".
# The main sections of this table are partials under "observations/show/namings"
#
# NOTE: some of the assembling of data could be in a presenter or component.
# NOTE: We don't even print this table unless @user is logged in.
# rubocop:disable Metrics/ModuleLength
module NamingsHelper
  def naming_header_row_content
    heading_html = tag.h4(:show_namings_proposed_names.t,
                          class: "panel-title")
    user_heading_html = tag.small(:show_namings_user.t)
    consensus_heading_html = tag.small(:show_namings_consensus.t)
    your_heading_html = tag.small(:show_namings_your_vote.t)

    {
      heading: heading_html,
      user_name: user_heading_html,
      consensus_vote: consensus_heading_html,
      your_vote: your_heading_html
    }
  end

  # NEW - needs a current consensus object
  def naming_row_content(user, consensus, naming)
    vote = consensus.users_vote(naming, user) || Vote.new(value: 0)
    consensus_favorite = consensus.consensus_naming
    favorite = consensus.owners_favorite?(naming)

    {
      id: naming.id,
      name: naming_name_html(user, naming),
      proposer: naming_proposer_html(naming),
      vote_tally: vote_tally_html(naming),
      your_vote: your_vote_html(naming, vote),
      eyes: vote_icons_html(naming, consensus_favorite, favorite),
      reasons: reasons_html(naming)
    }
  end

  # N+1: should not be checking permission here
  def naming_name_html(user, naming)
    if check_permission(naming)
      edit_link = modal_link_to(
        "obs_#{naming.observation_id}_naming_#{naming.id}",
        *edit_naming_tab(naming)
      )
      delete_link = naming_destroy_button(naming)
      proposer_links = tag.div(class: "text-nowrap") do
        ["[", edit_link, "|", delete_link, "]"].safe_join(" ")
      end
    else
      proposer_links = ""
    end

    [naming_name_link(user, naming), " ", proposer_links].safe_join
  end

  # see link_helper.rb destroy_button
  # Different from regular destroy button because of necessarily nested route
  def naming_destroy_button(naming)
    name = :DESTROY.t
    path = observation_naming_path(observation_id: naming.observation_id,
                                   id: naming.id)
    identifier = "destroy_naming_link_#{naming.id}"
    icon = link_icon(:remove)
    content = tag.span(name, class: "sr-only")

    html_options = {
      method: :delete, title: name,
      class: class_names(identifier, "text-danger"),
      form: { data: { turbo: true, turbo_confirm: :are_you_sure.t } },
      data: { toggle: "tooltip", placement: "top", title: name }
    }

    button_to(path, html_options) do
      [content, icon].safe_join
    end
  end

  # N+1: naming includes name
  def naming_name_link(user, naming)
    Textile.register_name(naming.name)
    link_with_query(
      naming.display_name_brief_authors(user).t.break_name.small_author,
      name_path(id: naming.name)
    )
  end

  # N+1: naming includes user
  def naming_proposer_html(naming)
    user_link = user_link(naming.user, naming.user.login,
                          { class: "btn btn-link text-wrap text-left px-0" })

    # row props have mobile-friendly labels
    [tag.small("#{:show_namings_user.t}: ", class: "visible-xs-inline mr-4"),
     user_link].safe_join
  end

  # N+1: naming includes votes. Should have been reloaded by VotesController.
  def vote_tally_html(naming)
    vote_tally =
      (if naming.votes&.length&.positive?
         "#{naming_votes_link(naming)} (#{num_votes_html(naming)})"
       else
         "(#{:show_namings_no_votes.t})"
       end).html_safe # has links

    # row props have mobile-friendly labels
    [tag.small("#{:show_namings_consensus.t}: ",
               class: "visible-xs-inline mr-4"),
     tag.span(vote_tally)].safe_join
  end

  # N+1: naming vote percent
  # Makes a link to observation_naming_vote_path for no-js.
  # The controller will render a modal if turbo request
  def naming_votes_link(naming)
    percent = "#{naming.vote_percent.round}%"

    modal_link_to("naming_votes_#{naming.id}", h(percent),
                  observation_naming_votes_path(
                    observation_id: naming.observation_id,
                    naming_id: naming.id
                  ),
                  class: "vote-percent btn btn-link px-0")
  end

  # N+1: naming includes votes
  def num_votes_html(naming)
    tag.span(naming.votes&.length,
             class: "vote-number", data: { id: naming.id })
  end

  # row props have mobile-friendly labels
  def your_vote_html(naming, vote)
    [tag.small("#{:show_namings_your_vote.t}: ",
               class: "visible-xs-inline-block"),
     naming_vote_form(naming, vote, context: "namings_table")].safe_join
  end

  # Naming Vote Form: a select that submits on change with Stimulus
  # a tiny form within a naming row for voting on this naming only
  # also called by matrix_box_vote_or_propose_ui
  # Stimulus just calls "requestSubmit", submits via Turbo
  # N+1: should not be checking permission here
  # N+1: vote is naming.users_vote, so should be an instance of Vote.
  # NamingsController#index iteration over namings in table_row
  # This may be a form_with(model: vote) so it gets an id, sent in url
  def naming_vote_form(naming, vote, context: "blank")
    vote_id = vote&.id
    method = vote_id ? :patch : :post
    can_vote = check_permission(naming)
    menu = if !can_vote || !vote || vote&.value&.zero?
             Vote.opinion_menu
           else
             Vote.confidence_menu
           end

    form_with(**naming_vote_form_args(naming, vote, method)) do |fv|
      [
        fv.select(:value, menu, {},
                  { class: "form-control w-100",
                    id: "vote_value_#{naming.id}",
                    data: { naming_vote_target: "select",
                            action: "naming-vote#sendVote" } }),
        hidden_field_tag(:context, context),
        tag.noscript do
          submit_button(form: fv, button: :show_namings_cast.l, class: "w-100",
                        data: { role: "save_vote",
                                naming_vote_target: "submit" })
        end
      ].safe_join
    end
  end

  private

  def naming_vote_form_args(naming, vote, method)
    args = {
      url: naming_vote_form_commit_url(naming, vote), method: method,
      id: "naming_vote_form_#{naming.id}",
      class: "naming-vote-form d-inline-block float-right float-sm-none",
      data: { turbo: true, controller: "naming-vote", naming_id: naming.id,
              localization: naming_vote_form_localizations }
    }
    # Only gets the :model arg if instance exists, else :scope
    args.merge(vote ? { model: vote } : { scope: :vote })
  end

  def naming_vote_form_localizations
    {
      lose_changes: :show_namings_lose_changes.l.tr("\n", " "),
      saving: :show_namings_saving.l
    }.to_json
  end

  # form can commit to update or create
  def naming_vote_form_commit_url(naming, vote)
    if vote&.id
      observation_naming_vote_path(
        observation_id: naming.observation_id, naming_id: naming.id, id: vote.id
      )
    else
      observation_naming_votes_path(
        observation_id: naming.observation_id, naming_id: naming.id
      )
    end
  end

  # May show both user and consensus icons
  def vote_icons_html(naming, consensus, favorite)
    [(favorite ? vote_icon_yours : ""),
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

  def observation_naming_buttons(user, obs)
    buttons = []
    buttons << propose_naming_link(
      obs.id,
      text: :show_namings_propose_new_name.t,
      btn_class: "btn btn-default btn-sm d-none d-sm-inline-block",
      context: "namings_table"
    )
    suggest = obs.thumb_image_id.present? &&
              (user.admin || MO.image_model_beta_testers.include?(user.id))
    buttons << suggest_namings_link(obs) if suggest
    buttons.safe_join(tag.br)
  end

  public

  # The new_naming_tab now has an icon. icon buttons send icon: true
  def propose_naming_link(obs_id, text: :create_naming.t,
                          context: "namings_table", icon: false,
                          btn_class: "btn btn-primary my-3")
    name, path, args = *new_naming_tab(
      obs_id, text: text, btn_class: btn_class, context: context
    )
    args = args.merge({ icon: nil }) unless icon

    modal_link_to("obs_#{obs_id}_naming", name, path, args)
  end

  # N+1: can't move the calculation of observation.image_ids
  # must query obs includes images, so don't update table-footer
  def suggest_namings_link(obs)
    localizations = {
      processing_images: :suggestions_processing_images.t,
      processing_image: :suggestions_processing_image.t,
      processing_results: :suggestions_processing_results.t,
      error: :suggestions_error.t
    }.to_json
    # NOTE: suggestions does not actually commit to this path, it's a js request
    results_url = add_query_param(
      naming_suggestions_for_observation_path(id: obs.id, names: :xxx)
    )

    button_tag(
      :show_namings_suggest_names.l,
      type: :button, class: "btn btn-default btn-sm mt-2",
      data: { results_url: results_url,
              localization: localizations,
              image_ids: obs.image_ids.to_json,
              controller: "suggestions", # Stimulus controller
              action: "suggestions#suggestTaxa" }
    )
  end

  private

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

  public

  # NAMING FORM/OBS FORM
  def naming_form_reasons_fields(f_r, reasons)
    reasons.values.sort_by(&:order).map do |rsn|
      tag.div(class: "naming-reason-container",
              data: {
                controller: "naming-reason", # stimulus cntrlr explains event
                action: "$shown.bs.collapse->naming-reason#focusInput"
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
# rubocop:enable Metrics/ModuleLength
