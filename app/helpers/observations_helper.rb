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
  def show_obs_title(obs)
    capture do
      concat(:show_observation_header.t)
      concat(" #{obs.id || "?"}: ")
      concat(obs_title_consensus_id(obs.name))
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

  private

  # name portion of Observation title
  def obs_title_consensus_id(name)
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
        # cop disabled per https://github.com/MushroomObserver/mushroom-observer/pull/1060#issuecomment-1179410808
        concat(" (#{:show_observation_site_id.t})") if @owner_naming # rubocop:disable Rails/HelperInstanceVariable
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

  def link_to_display_name_brief_authors(name)
    link_to(name.display_name_brief_authors.t,
            show_name_path(id: name.id))
  end

  def link_to_display_name_without_authors(name)
    link_to(name.display_name_without_authors.t,
            show_name_path(id: name.id))
  end

  public ######################################################################

  ##### Observation Naming "table" content #########
  def observation_naming_header_row(observation, logged_in)
    any_names = observation.namings&.length&.positive?
    heading = (if any_names
                 :show_namings_proposed_names.t
               else
                 :show_namings_no_names_yet.t
               end)
    heading_html = content_tag(:h4, heading, class: "table-title mb-0")
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
      name: name_html(naming),
      proposer: proposer_html(naming),
      consensus_vote: consensus_vote_html(naming),
      your_vote: logged_in ? your_vote_html(naming) : "",
      eyes: eyes_html(observation, naming),
      reasons: reasons_html(naming)
    }
  end

  def observation_naming_buttons(observation, do_suggestions)
    buttons = []
    buttons << link_with_query(:show_namings_propose_new_name.t,
                               new_observation_naming_path(
                                 observation_id: observation.id
                               ),
                               { class: "btn btn-default" })
    if do_suggestions
      buttons << link_to(:show_namings_suggest_names.l, "#",
                         { data: { role: "suggest_names" },
                           class: "btn btn-default" })
    end
    buttons.safe_join(tag(:br))
  end

  private

  def name_html(naming)
    Textile.register_name(naming.name)
    name_link = link_with_query(
      naming.display_name_brief_authors.t.break_name.small_author,
      show_name_path(id: naming.name)
    )

    if check_permission(naming)
      edit_link = link_with_query(:EDIT.t, edit_naming_path(id: naming.id),
                                  class: "edit_naming_link_#{naming.id}")
      delete_link = destroy_button(target: naming)
      proposer_links = [tag(:br),
                        "[", edit_link, " | ", delete_link, "]"].safe_join
    else
      proposer_links = ""
    end

    [name_link, proposer_links].safe_join
  end

  def proposer_html(naming)
    user_link = user_link(naming.user, naming.user.login)

    # row props have mobile-friendly labels
    [content_tag(:small, "#{:show_namings_user.t}: ",
                 class: "visible-xs-inline mr-4"),
     content_tag(:strong, user_link)].safe_join
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

  def pct_html(naming)
    percent = naming.vote_percent.round.to_s + "%"

    if can_do_ajax?
      content_tag(:button, h(percent),
                  class: "vote-percent btn btn-link",
                  data: { toggle: "modal",
                          target: "#show_votes_#{naming.id}" })
    else
      link_with_query(h(percent),
                      naming_vote_path(naming_id: naming.id),
                      { class: "vote-percent" })
    end
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
            locals: { naming: naming,
                      can_vote: check_permission(naming) })].safe_join
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
