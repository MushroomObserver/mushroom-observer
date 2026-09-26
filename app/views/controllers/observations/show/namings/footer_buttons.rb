# frozen_string_literal: true

# First card-footer row of the namings sub-panel: the
# "Propose new name" button on the left and the consensus-help
# blurb on the right. Admins / image-model beta testers also see
# a "Suggest names" button stacked under the propose button. On
# mobile, the propose button and the consensus-help text are both
# hidden by default -- the help text lives behind a toggle instead.
class Views::Controllers::Observations::Show::Namings::FooterButtons < Views::Base
  prop :user, ::User
  prop :obs, ::Observation

  # `xs: 12` on both -- the buttons column is entirely `d-none` on
  # mobile (propose is `d-sm-block`, suggest is admin-only), so
  # `col: true` at `xs` reserved half the row for nothing.
  def view_template
    Row do
      Column(sm: 11) do
        Row do
          Column(xs: 12, md: 4) { render_buttons }
          Column(xs: 12, md: 8) { render_consensus_help }
        end
      end
    end
  end

  private

  # Always at least the propose-naming button; the suggest-names
  # button only renders when the user is allowed to use it.
  def render_buttons
    render_propose_button
    return unless suggest_namings_enabled?

    render_suggest_button
  end

  # Text-button variant of the propose-naming link (icon-only
  # variant lives in the panel `Header` for mobile).
  def render_propose_button
    div(class: "d-none d-sm-block mb-2") do
      Button(
        type: :modal,
        name: :show_namings_propose_new_name.t,
        target: new_observation_naming_path(
          observation_id: @obs.id,
          context: "namings_table"
        ),
        modal_id: "obs_#{@obs.id}_naming",
        size: :sm,
        class: "propose-naming-link"
      )
    end
  end

  # Gating: a thumb image must exist (so
  # the JS has something to send to the model) AND the user must
  # be admin or on the image-model beta-tester list.
  def suggest_namings_enabled?
    @obs.thumb_image_id.present? &&
      (@user.admin || ::MO.image_model_beta_testers.include?(@user.id))
  end

  # "Suggest names" kicks off a JS-driven image-classifier request
  # — the button doesn't actually submit a form, it dispatches a
  # Stimulus `suggestions#suggestTaxa` action that fetches via
  # `data-results-url` and replaces page content.
  def render_suggest_button
    Button(
      name: :show_namings_suggest_names.l,
      size: :sm,
      class: "mb-2",
      data: suggest_button_data
    )
  end

  def suggest_button_data
    {
      results_url: suggest_results_url,
      localization: suggest_localizations,
      image_ids: @obs.image_ids.to_json,
      controller: "suggestions",
      action: "suggestions#suggestTaxa"
    }
  end

  # NOTE: the URL is never actually visited — the JS uses it as a
  # template for its fetch — so the placeholder `names: :xxx`
  # segment matches the naming endpoint contract.
  def suggest_results_url
    add_q_param(
      naming_suggestions_for_observation_path(id: @obs.id, names: :xxx)
    )
  end

  def suggest_localizations
    {
      processing_images: :suggestions_processing_images.t,
      processing_image: :suggestions_processing_image.t,
      processing_results: :suggestions_processing_results.t,
      error: :suggestions_error.t
    }.to_json
  end

  # Collapsed by default, behind a mobile-only toggle -- `d-sm-block`
  # (an `!important` utility) overrides the collapse's plain
  # `display: none` at `sm`+, so desktop always shows it open.
  def render_consensus_help
    render_mobile_help_toggle
    Collapsible(id: "namings_consensus_help",
                class: "card-text small d-sm-block") do
      trusted_html(:show_namings_consensus_help.t)
    end
  end

  def render_mobile_help_toggle
    Link(type: :collapse_toggle,
         target_id: "namings_consensus_help",
         button: :link, size: :sm,
         class: "d-sm-none") do
      plain(:show_namings_vote_on_names.t)
      Icon(type: :info, wrap_class: "icon-text-gap")
    end
  end
end
