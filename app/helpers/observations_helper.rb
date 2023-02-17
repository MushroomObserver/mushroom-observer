# frozen_string_literal: true

# helpers for show Observation view
module ObservationsHelper
  ##### Portion of page title that includes consensus naming (site id) #########
  #
  # Depends on whether consensus is deprecated and user preferences include
  # showing Observer's Preference
  #
  # Consensus not deprecated, observer preference not shown:
  #   Observation nnn: Aaa bbb Author(s)
  # Consensus deprecated, observer preference not shown:
  #   Observation nnn: Ccc ddd Author(s) (Site ID) (Aaa bbb)
  # Observer preference shown, consensus not deprecated:
  #   Observation nnn: Aaa bbb Author(s) (Site ID)
  def show_obs_title(obs:, owner_naming: nil)
    capture do
      concat(:show_observation_header.t)
      concat(" #{obs.id || "?"}: ")
      concat(obs_title_consensus_id(name: obs.name, owner_naming: owner_naming))
    end
  end

  ##### Portion of page title that includes user's naming preference #########

  # Observer Preference: Hydnum repandum
  def owner_naming_line(obs)
    return unless User.current&.view_owner_id

    capture do
      concat(:show_observation_owner_id.t + ": ")
      concat(owner_favorite_or_explanation(obs).t)
    end
  end

  # gathers the user's @votes indexed by naming
  def gather_users_votes(obs, user = nil)
    return [] unless user

    obs.namings.each_with_object({}) do |naming, votes|
      votes[naming.id] =
        naming.votes.find { |vote| vote.user_id == user.id } ||
        Vote.new(value: 0)
    end
  end

  private

  # name portion of Observation title
  def obs_title_consensus_id(name:, owner_naming: nil)
    if name.deprecated &&
       (current_name = name.best_preferred_synonym).present?
      capture do
        concat(link_to_display_name_brief_authors(name))
        # Differentiate deprecated consensus from preferred name
        concat(" (#{:show_observation_site_id.t})")
        concat(" ") # concat space separately, else `.t` strips it
        concat("(")
        concat(link_to_display_name_without_authors(current_name))
        concat(")")
      end
    else
      capture do
        concat(link_to_display_name_brief_authors(name))
        # Differentiate this Name from Observer Preference
        concat(" (#{:show_observation_site_id.t})") if owner_naming
      end
    end
  end

  def owner_favorite_or_explanation(obs)
    if (name = obs.owner_preference)
      link_to_display_name_brief_authors(name)
    else
      :show_observation_no_clear_preference
    end
  end

  public

  def link_to_display_name_brief_authors(name)
    link_to(name.display_name_brief_authors.t,
            name_path(id: name.id))
  end

  def link_to_display_name_without_authors(name)
    link_to(name.display_name_without_authors.t,
            name_path(id: name.id))
  end

  ##### Observation Naming "table" content #########
  def observation_naming_header_row(observation, logged_in)
    any_names = observation.namings&.length&.positive?
    heading = (if any_names
                 :show_namings_proposed_names.t
               else
                 :show_namings_no_names_yet.t
               end)
    heading_html = content_tag(:h4, heading, class: "table-title my-0")
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
      eyes: eyes_html(observation, naming),
      reasons: reasons_html(naming)
    }
  end

  # the "propose_naming_button" is turned into a modal trigger by JS
  def observation_naming_buttons(observation, do_suggestions)
    buttons = []
    buttons << render(partial: "observations/namings/propose_button",
                      locals: { observation: observation }, layout: false)
    if do_suggestions
      buttons << link_to(:show_namings_suggest_names.l, "#",
                         { data: { role: "suggest_names" },
                           class: "btn btn-default mt-2" })
    end
    buttons.safe_join(tag.br)
  end

  private

  def naming_name_html(naming)
    Textile.register_name(naming.name)

    if check_permission(naming)
      edit_link = link_with_query(:EDIT.t, edit_naming_path(id: naming.id),
                                  class: "edit_naming_link_#{naming.id}")
      delete_link = destroy_button(target: naming, remote: true)
      proposer_links = [tag.br,
                        "[", edit_link, " | ", delete_link, "]"].safe_join
    else
      proposer_links = ""
    end

    [naming_name_link(naming), proposer_links].safe_join
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
    [content_tag(:small, "#{:show_namings_user.t}: ",
                 class: "visible-xs-inline mr-4"),
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
    [content_tag(:small, "#{:show_namings_consensus.t}: ",
                 class: "visible-xs-inline mr-4"),
     content_tag(:span, consensus_votes)].safe_join
  end

  # Makes a link to naming_vote_path for no-js.
  # The controller will render a modal if js request
  def pct_html(naming)
    percent = naming.vote_percent.round.to_s + "%"

    link_with_query(h(percent),
                    naming_vote_path(naming_id: naming.id),
                    { class: "vote-percent btn btn-link px-0",
                      onclick: "MOEvents.whirly();",
                      remote: true })
  end

  def num_votes_html(naming)
    content_tag(:span, naming.votes&.length,
                { class: "vote-number", data: { id: naming.id } })
  end

  def your_vote_html(naming)
    # row props have mobile-friendly labels
    [content_tag(:small, "#{:show_namings_your_vote.t}: ",
                 class: "visible-xs-block"),
     render(partial: "observations/namings/votes/form",
            locals: { naming: naming })].safe_join
  end

  def eyes_html(observation, naming)
    consensus = observation.consensus_naming

    [(observation.owners_favorite?(naming) ? image_tag("eye3.png") : ""),
     (naming == consensus ? image_tag("eyes3.png") : "")].safe_join
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
