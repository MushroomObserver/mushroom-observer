# frozen_string_literal: true

# Naming vote form — a tiny Stimulus-rooted `<form>` containing a
# `<select>` that auto-submits via Turbo when the user picks a
# value. The select shows either `Vote.opinion_menu` (for
# unconfirmed / no-opinion voters) or `Vote.confidence_menu` (for
# users who've already expressed a non-zero opinion).
#
# Rendered from two places:
#
# - `Views::Controllers::Observations::Show::Namings::Row` — the
#   "Your vote" column of the namings sub-panel on the obs show
#   page. Context: `"namings_table"`.
# - `Components::Matrix::Box` (`#render_identify_ui`) — the
#   vote-or-propose UI rendered inside a matrix box on index
#   pages. Context: `"matrix_box"`.
#
module Views::Controllers::Observations::Namings::Votes
  class Form < ::Components::ApplicationForm
    # @param naming [::Naming] the naming being voted on
    # @param user [::User, nil] the current viewer. Drives the
    #   menu-shape branch — the naming's proposer (or an admin)
    #   defaults to the confidence menu when they already have a
    #   non-zero vote; everyone else stays on the wider opinion
    #   menu. Pass `@user` from the consuming view.
    # @param vote [::Vote, nil] the current user's existing vote, if
    #   any; nil means this is a fresh vote → POST instead of PATCH
    # @param context [String] arbitrary marker submitted alongside
    #   the vote — used by the controller to decide which Turbo
    #   Stream response to send back. Either `"namings_table"` (for
    #   the show page panel) or `"matrix_box"` (for matrix box UI).
    def initialize(naming:, user:, vote: nil, context: "blank")
      @naming = naming
      @user = user
      @vote = vote
      @context = context
      # Pass the actual Vote (existing or fresh) so Superform picks
      # the right HTTP method (PATCH vs POST) and resolves the
      # `vote[value]` field name from the model.
      super(vote || ::Vote.new,
            id: "naming_vote_form_#{@naming.id}",
            local: false,
            class: "naming-vote-form d-inline-block " \
                   "float-right float-sm-none",
            data: form_data)
    end

    # Form action: PATCH to a vote when one exists, POST to the
    # namings/votes collection when creating a fresh vote.
    def form_action
      if @vote&.id
        observation_naming_vote_path(
          observation_id: @naming.observation_id,
          naming_id: @naming.id, id: @vote.id
        )
      else
        observation_naming_votes_path(
          observation_id: @naming.observation_id, naming_id: @naming.id
        )
      end
    end

    def view_template
      render_vote_select
      hidden_field("context", value: @context)
      render_no_script_fallback
    end

    private

    # `data-controller="naming-vote"` roots the JS that watches the
    # select for change events. `localization:` is read by the JS
    # to pick localized strings for the confirm dialog / inflight
    # state. `naming_id:` lets the JS find sibling rows to refresh.
    def form_data
      {
        controller: "naming-vote",
        naming_id: @naming.id,
        localization: form_localizations
      }
    end

    def form_localizations
      {
        lose_changes: :show_namings_lose_changes.l.tr("\n", " "),
        saving: :saving.ti
      }.to_json
    end

    # `label: false` skips the form-group wrapper — this select is
    # an inline atomic widget, not a labeled form field.
    def render_vote_select
      select_field(
        :value, vote_menu, label: false,
                           id: "vote_value_#{@naming.id}",
                           class: "w-100",
                           data: { naming_vote_target: "select",
                                   action: "naming-vote#sendVote" }
      )
    end

    # Opinion menu (the wider `[no opinion | confidence range]`
    # listing) appears whenever the user hasn't yet committed to a
    # specific confidence value: when they're not the proposer (or
    # admin), when they have no vote, or when their stored vote is
    # the "no opinion" sentinel zero. The proposer view defaults
    # to the tighter confidence menu (`[−3, …, +3]`) once they've
    # cast a real opinion.
    def vote_menu
      if !proposer_view? || !@vote || @vote.value.to_f.zero?
        ::Vote.opinion_menu
      else
        ::Vote.confidence_menu
      end
    end

    # True when the viewer owns this naming (or is admin). Written out
    # explicitly so the form is self-contained — no controller-side
    # ivar dependency.
    def proposer_view?
      return false unless @user

      @user.id == @naming.user_id || in_admin_mode?
    end

    # JS-disabled fallback: rendered inside a `<noscript>` so the
    # select can still be submitted by a real button when JS is
    # off. `naming_vote_target="submit"` lets the JS hide / disable
    # the button when it takes over.
    def render_no_script_fallback
      noscript do
        submit(:show_namings_cast.l, class: "w-100",
                                     data: no_script_submit_data)
      end
    end

    def no_script_submit_data
      { role: "save_vote", naming_vote_target: "submit" }
    end
  end
end
