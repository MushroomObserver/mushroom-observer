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

  # the "propose-naming-button" is remote: true to send js request
  def observation_naming_buttons(observation, do_suggestions)
    buttons = []
    buttons << propose_naming_link(observation.id,
                                   text: :show_namings_propose_new_name.t,
                                   btn_class: "btn-default btn-sm",
                                   context: "namings_table")
    if do_suggestions
      buttons << link_to(:show_namings_suggest_names.l, "#",
                         { data: { role: "suggest_names" },
                           class: "btn btn-default btn-sm mt-2" })
    end
    buttons.safe_join(tag.br)
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
  # fires the special rails-ujs submit event for remote submit
  # requires a native js (not jQuery) element, form is parent of select
  # Turbo: check how this should submit
  def naming_vote_form(naming, vote, context: "blank")
    menu = Vote.confidence_menu
    can_vote = check_permission(naming)
    menu = [Vote.no_opinion] + menu if !can_vote || !vote || vote&.value&.zero?

    form_with(url: naming_vote_path(naming_id: naming.id), method: :patch,
              local: false, id: "naming_vote_#{naming.id}",
              class: "naming-vote-form") do |f|
      [
        fields_for(:vote) do |fv|
          fv.select(:value, menu, {},
                    { class: "form-control w-100",
                      onchange: "Rails.fire(this.closest('form'), 'submit')",
                      data: { role: "change_vote", id: naming.id } })
        end,
        hidden_field_tag(:context, context),
        submit_button(form: f, button: :show_namings_cast.l, class: "w-100",
                      data: { role: "save_vote" })
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
end
