# frozen_string_literal: true

# One row of the obs-show namings sub-panel. Renders the content of a
# `Components::ListGroup` item — the wrapping `<div class="list-group-
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

  # Shared by `render_main_columns` and `render_mobile_label_row` --
  # they need matching `xs:` widths to keep each mobile label above
  # its value (two separate `.row`s don't share column tracks
  # otherwise). No `xs:` for `proposer`: that column is hidden below
  # `sm` (see `render_mobile_proposer_prefix`), and `xs:` for the
  # other three sums to 12 without it.
  COLUMN_WIDTHS = {
    name: { xs: 5, sm: 4 },
    proposer: { sm: 3 },
    votes: { xs: 3, sm: 2 },
    your_vote: { xs: 4, sm: 3 }
  }.freeze

  def view_template
    Row(class: "d-flex align-items-center naming-row",
        id: "observation_naming_#{primary.id}") do
      Column(col: true, sm: 11) do
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
  # itself. The name-cell uses this to drive the InlineCRUDLinks
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
    render_mobile_label_row
    Row(class: "d-flex align-items-center naming-columns") do
      Column(**COLUMN_WIDTHS[:name]) { render_name_cell }
      Column(**COLUMN_WIDTHS[:proposer], class: "d-none d-sm-block") do
        render_proposer_cell
      end
      Column(**COLUMN_WIDTHS[:votes]) { render_vote_tally_cell }
      Column(**COLUMN_WIDTHS[:your_vote]) { render_your_vote_cell }
    end
  end

  # Mobile column-header substitute -- a separate row, not each cell
  # printing a label, so `align-items-end` can bottom-align every
  # label (matches `Show::Namings::Header`'s row). The value row
  # uses `align-items-center` instead, for its content.
  def render_mobile_label_row
    Row(class: "d-flex d-sm-none align-items-end naming-columns") do
      Column(xs: COLUMN_WIDTHS[:name][:xs])
      Column(xs: COLUMN_WIDTHS[:votes][:xs]) do
        render_mobile_label(:votes.ti)
      end
      Column(xs: COLUMN_WIDTHS[:your_vote][:xs]) do
        render_mobile_label(:show_namings_your_vote.t)
      end
    end
  end

  def render_reasons_row
    div(class: "naming-reasons small mt-1") do
      render_mobile_proposer_prefix
      render_reasons
    end
  end

  # Omitted for a MergedNaming with multiple proposers, where
  # `@naming.user` is nil.
  def render_mobile_proposer_prefix
    proposer = @naming.user
    return unless proposer

    span(class: "d-inline d-sm-none") do
      plain(:show_namings_proposed_by.t(user: proposer.unique_text_name))
      whitespace
    end
  end

  def render_eyes_column
    Column(sm: 1, class: "d-none d-sm-block px-sm-0") { render_eyes }
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
    render_mod_links(name_for_link) if local
  end

  def render_name_link(naming)
    a(href: url_for(name_path(id: naming.name))) do
      trusted_html(naming.display_name_brief_authors(@user).t.small_author)
    end
  end

  def render_mod_links(naming)
    InlineCRUDLinks(target: naming, user: @user)
  end

  # ---- proposer cell --------------------------------------------

  # Hidden below `sm` -- `render_mobile_proposer_prefix` covers
  # mobile instead.
  def render_proposer_cell
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
    Button(
      type: :get,
      target: url_for(occurrence_path(@naming.observation.occurrence)),
      name: :show_observation_matching_observations.l,
      variant: :link,
      class: "text-wrap text-left px-0"
    )
  end

  def render_single_proposer_link
    proposer = @naming.user
    Link(type: :user,
         user: proposer,
         name: proposer.login,
         button: :link,
         attributes: { class: "text-wrap text-left px-0" })
  end

  # ---- vote tally cell ------------------------------------------

  def render_vote_tally_cell
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
    Button(
      type: :modal,
      name: "#{@naming.vote_percent.round}%",
      target: vote_percent_modal_path,
      modal_id: "naming_votes_#{primary.id}",
      variant: :link, class: "vote-percent px-0"
    )
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

  # `primary`, not the MergedNaming, so the form binds to a Naming
  # record.
  def render_your_vote_cell
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

  def render_mobile_label(text)
    small { append_colon(text) }
  end
end
