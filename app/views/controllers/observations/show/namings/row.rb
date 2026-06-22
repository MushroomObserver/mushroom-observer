# frozen_string_literal: true

# One row of the obs-show namings sub-panel. Renders the content of a
# `Components::ListGroup::Base` item — the wrapping `<div class="list-group-
# item">` is supplied by the parent `Show::Namings::Rows` via
# `list.item(id: …) { render(Row.new(…)) }`.
#
class Views::Controllers::Observations::Show::Namings::Row < Views::Base
  # `naming` can be either a plain `Naming` (single observation) or
  # an `Observation::MergedNaming` (occurrence-grouped roll-up of
  # several namings across sibling observations). The downstream
  # logic branches on the type via `is_a?` checks.
  prop :naming, _Union(::Naming, ::Observation::MergedNaming)
  prop :user, ::User
  prop :consensus, ::Observation::NamingConsensus

  def view_template
    div(class: "row align-items-center naming-row",
        id: "observation_naming_#{primary.id}") do
      div(class: "col col-sm-11") do
        render_main_columns
        render_reasons_row
      end
      render_eyes_column
    end
  end

  private

  # ---- derived state --------------------------------------------

  # The underlying Naming used to anchor selectors (DOM id, modal
  # ids, votes-modal route). For a MergedNaming, the "primary"
  # naming represents the focal-observation member of the group.
  def primary
    @primary ||= if @naming.is_a?(::Observation::MergedNaming)
                   @naming.primary_naming
                 else
                   @naming
                 end
  end

  # The naming whose proposer / edit links belong to the current
  # observation. For a MergedNaming this is the sibling that lives
  # on the focal observation, if any; for a plain Naming it's
  # itself. The name-cell uses this to drive the InlineModLinks
  # `editable` decision — only local namings get edit/destroy
  # controls because cross-observation edits aren't reachable
  # from here.
  def local
    @local ||= if @naming.is_a?(::Observation::MergedNaming)
                 @naming.local_naming
               else
                 @naming
               end
  end

  # User's best vote across merged namings, or their direct vote on
  # the focal naming. `Vote.new(value: 0)` is the "no opinion"
  # sentinel that drives the Votes::Form into the opinion menu.
  def user_vote
    @user_vote ||= if @naming.is_a?(::Observation::MergedNaming)
                     @naming.users_best_vote(@user) ||
                       ::Vote.new(value: 0)
                   else
                     @consensus.users_vote(@naming, @user) ||
                       ::Vote.new(value: 0)
                   end
  end

  def consensus_favorite
    @consensus_favorite ||= @consensus.consensus_naming
  end

  def owners_favorite?
    @owners_favorite ||= @consensus.owners_favorite?(primary)
  end

  # ---- top-level layout pieces ----------------------------------

  def render_main_columns
    div(class: "row align-items-center") do
      div(class: "col col-sm-4") { render_name_cell }
      div(class: "col col-sm-3") { render_proposer_cell }
      div(class: "col col-sm-2") { render_vote_tally_cell }
      div(class: "col col-sm-3") { render_your_vote_cell }
    end
  end

  def render_reasons_row
    div(class: "naming-reasons small mt-1") { render_reasons }
  end

  def render_eyes_column
    div(class: "col-sm-1 d-none d-sm-block px-sm-0") { render_eyes }
  end

  # ---- name cell -------------------------------------------------

  # Renders the name link followed by an optional `[edit | destroy]`
  # inline-mod-links group. The group only appears for `local`
  # namings — cross-observation merged-naming rows don't expose
  # mod controls (those edits live on the originating obs).
  def render_name_cell
    name_for_link = local || primary
    ::Textile.register_name(name_for_link.name)
    render_name_link(name_for_link)
    whitespace
    render_mod_links(name_for_link) if local
  end

  def render_name_link(naming)
    a(href: url_for(name_path(id: naming.name))) do
      trusted_html(
        naming.display_name_brief_authors(@user).
          t.break_name.small_author
      )
    end
  end

  def render_mod_links(naming)
    div(class: "text-nowrap") do
      render(Components::Link::InlineMod.new(
               target: naming, user: @user, indent: false
             ))
    end
  end

  # ---- proposer cell --------------------------------------------

  # Two branches: a MergedNaming with multiple proposers links to
  # the occurrence's "matching observations" page; everything else
  # renders the single proposer as a UserLink. Both prefix a
  # mobile-only "User: " label so the row reads cleanly when the
  # column headers are hidden on `xs`.
  def render_proposer_cell
    render_mobile_label(:show_namings_user.t)
    if merged_with_multiple_proposers?
      render_matching_observations_link
    else
      render_single_proposer_link
    end
  end

  def merged_with_multiple_proposers?
    @naming.is_a?(::Observation::MergedNaming) &&
      @naming.multiple_proposers?
  end

  def render_matching_observations_link
    render(Components::Button.new(
             type: :get,
             target: url_for(occurrence_path(@naming.observation.occurrence)),
             name: :show_observation_matching_observations.l,
             variant: :btn_link,
             class: "text-wrap text-left px-0"
           ))
  end

  def render_single_proposer_link
    proposer = @naming.user
    render(Components::Link::Object::User.new(
             user: proposer, name: proposer.login,
             attributes: { class: proposer_link_classes }
           ))
  end

  def proposer_link_classes
    "btn btn-link text-wrap text-left px-0"
  end

  # ---- vote tally cell ------------------------------------------

  # "Consensus" column on `sm+`. Mobile-prefixes a "Consensus: "
  # small-text label so the row stays readable when the column
  # headers are hidden.
  def render_vote_tally_cell
    render_mobile_label(:show_namings_consensus.t)
    span { render_vote_tally_inner }
  end

  def render_vote_tally_inner
    if any_votes?
      render_vote_percent_link
      plain(" (")
      render_num_votes
      plain(")")
    else
      plain("(#{:show_namings_no_votes.t})")
    end
  end

  # Vote-percent link opens a modal showing the per-user vote
  # breakdown. The modal id pins to the primary naming so the
  # backing turbo_stream response can target it deterministically.
  def any_votes?
    votes = @naming.votes
    !votes.nil? && votes.length.positive?
  end

  def render_vote_percent_link
    render(Components::Button.new(
             type: :modal,
             name: "#{@naming.vote_percent.round}%",
             target: vote_percent_modal_path,
             modal_id: "naming_votes_#{primary.id}",
             variant: :btn_link, class: "vote-percent px-0"
           ))
  end

  def vote_percent_modal_path
    observation_naming_votes_path(observation_id: primary.observation_id,
                                  naming_id: primary.id)
  end

  def render_num_votes
    span(class: "vote-number", data: { id: primary.id }) do
      plain(@naming.votes.length.to_s)
    end
  end

  # ---- your-vote cell -------------------------------------------

  # Mobile label + the actual Votes::Form. Pass the form `primary`
  # (not the MergedNaming) so the form binds to a real Naming
  # record and routes correctly.
  def render_your_vote_cell
    render_mobile_label(:show_namings_your_vote.t, block: true)
    render(::Views::Controllers::Observations::Namings::Votes::Form.new(
             naming: primary, user: @user, vote: user_vote,
             context: "namings_table"
           ))
  end

  # ---- eyes column ----------------------------------------------

  # Two stacking icon-divs: "your favorite" eye and "consensus
  # favorite" eye. Either can be hidden if the corresponding
  # condition doesn't apply.
  def render_eyes
    render_eye_icon("vote-icon-yours") if owners_favorite?
    render_eye_icon("vote-icon-consensus") if primary == consensus_favorite
  end

  # Triple-nested div is the legacy markup needed by the
  # `.vote-icon-*` CSS for the centered, fixed-size eye glyph.
  # Sizer/width split is what gives the icon its inherent
  # aspect ratio without depending on the parent column width.
  def render_eye_icon(modifier_class)
    div(class: "vote-icon-width") do
      div(class: "vote-icon-sizer") do
        div(class: modifier_class)
      end
    end
  end

  # ---- reasons row ----------------------------------------------

  def render_reasons
    if @naming.is_a?(::Observation::MergedNaming)
      render_merged_reasons
    else
      render_simple_reasons(@naming.reasons_array.select(&:used?))
    end
  end

  # Merged-naming reasons are grouped by the source observation
  # they came from; each group prints a "From MO <id>:" header
  # before its reasons. Groups with no source obs (orphaned)
  # render their reasons without a header.
  def render_merged_reasons
    @naming.grouped_reasons.each do |obs, reasons|
      render_reasons_source_label(obs) if obs
      render_simple_reasons(reasons)
    end
  end

  def render_reasons_source_label(obs)
    div(class: "mt-2") do
      small(class: "text-muted") do
        plain("From ")
        a(href: url_for(permanent_observation_path(obs.id))) do
          plain("MO #{obs.id}")
        end
        plain(":")
      end
    end
  end

  def render_simple_reasons(reasons)
    reasons.each do |reason|
      div { trusted_html(simple_reason_text(reason)) }
    end
  end

  # `.html_safe` on `reason.notes` is load-bearing: the trailing
  # `.tl` (textile-line) renderer needs unescaped textile markup
  # to interpret; without `html_safe` the `#{…}` interpolation
  # double-escapes `<i>` / `<b>` tags that legitimately appear in
  # user-typed reason notes
  def simple_reason_text(reason)
    return reason.label.t if reason.notes.blank?

    "#{reason.label.l}: #{reason.notes.to_s.html_safe}".tl # rubocop:disable Rails/OutputSafety
  end

  # ---- shared bits ----------------------------------------------

  # Column-header replacement for `xs` viewports — the original
  # column labels are hidden on small screens, so each cell
  # prefixes its content with a tiny label that says what the
  # value means.
  def render_mobile_label(text, block: false)
    vis = block ? "visible-xs-inline-block" : "visible-xs-inline mr-4"
    small(class: vis) { plain("#{text}: ") }
  end
end
