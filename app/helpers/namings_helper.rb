# frozen_string_literal: true

# helpers for namings view
# TODO: some of this should be in a presenter
module NamingsHelper
  ##### Observation Naming "table" content #########
  def observation_naming_header_row(logged_in)
    heading_html = content_tag(:h6, :show_namings_proposed_names.t)
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

  def observation_naming_row(observation, naming, logged_in)
    {
      name: naming_name_html(naming),
      proposer: naming_proposer_html(naming),
      consensus_vote: consensus_vote_html(naming),
      your_vote: logged_in ? your_vote_html(naming) : "",
      eyes: vote_icons_html(observation, naming),
      reasons: reasons_html(naming)
    }
  end

  # the "propose-naming-button" is remote: true to send js request
  def observation_naming_buttons(observation, do_suggestions)
    buttons = []
    buttons << propose_naming_link(observation.id,
                                   text: :show_namings_propose_new_name.t,
                                   btn_class: "btn-primary btn-sm",
                                   context: "namings_table")
    if do_suggestions
      buttons << link_to(:show_namings_suggest_names.l, "#",
                         { data: { role: "suggest_names" },
                           class: "btn btn-primary btn-sm" })
    end
    buttons.safe_join(content_tag(:div, "", class: "p-1"))
  end

  private

  def naming_name_html(naming)
    Textile.register_name(naming.name)

    if check_permission(naming)
      edit_link = edit_button(name: :EDIT.t, target: naming, icon: :edit,
                              remote: true, onclick: "MOEvents.whirly();")
      delete_link = destroy_button(target: naming, remote: true, icon: :destroy)
      proposer_links = tag.span(class: "small text-nowrap") do
        [edit_link, " | ", delete_link].safe_join
      end
    else
      proposer_links = ""
    end

    [naming_name_link(naming), " ", proposer_links].safe_join
  end

  def naming_name_link(naming)
    link_with_query(name_path(id: naming.name)) do
      tag.h6(
        naming.display_name_brief_authors.t.break_name.small_author,
        class: "mb-0"
      )
    end
  end

  def naming_proposer_html(naming)
    user_link = user_link(naming.user, naming.user.login,
                          { class: "py-md-1 font-weight-bold" })

    # row props have mobile-friendly labels
    [tag.small("#{:show_namings_user.t}: ",
               class: "d-inline d-md-none mr-4"),
     user_link].safe_join
  end

  def consensus_vote_html(naming)
    consensus_votes =
      (if naming.votes&.length&.positive?
         pct_html(naming)
       else
         "(#{:show_namings_no_votes.t})"
       end).html_safe # has links

    # row props have mobile-friendly labels
    [tag.small("#{:show_namings_consensus.t}: ",
               class: "d-inline d-md-none mr-4"),
     tag.span(consensus_votes)].safe_join
  end

  # Makes a link to naming_vote_path for no-js.
  # The controller will render a modal if js request
  def pct_html(naming)
    percent = "#{naming.vote_percent.round}%"

    link_with_query(naming_vote_path(naming_id: naming.id),
                    class: "vote-percent btn btn-link px-0",
                    onclick: "MOEvents.whirly();", remote: true) do
                      [h(percent), num_votes_html(naming)].safe_join(" ")
                    end
  end

  def num_votes_html(naming)
    content_tag(:span, class: "vote-number-text") do
      ["(",
       tag.span(naming.votes&.length,
                class: "vote-number", data: { id: naming.id }),
       ")"].safe_join
    end
  end

  def your_vote_html(naming)
    # row props have mobile-friendly labels
    [tag.small("#{:show_namings_your_vote.t}: ", class: "d-block d-md-none"),
     render(partial: "observations/namings/votes/form",
            locals: { naming: naming, classes: "form-control-sm",
                      context: "namings_table" })].safe_join
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
        [
          "#{reason.label.l}: ",
          reason.notes.to_s
        ].safe_join.tl # may have links
      end
    end

    reasons.map { |reason| content_tag(:div, reason) }.safe_join
  end
end
