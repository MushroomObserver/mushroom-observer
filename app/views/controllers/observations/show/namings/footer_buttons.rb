# frozen_string_literal: true

# First panel-footer row of the namings sub-panel: the
# "Propose new name" button on the left and the consensus-help
# blurb on the right. Admins / image-model beta testers also see
# a "Suggest names" button stacked under the propose button.
#
# Replaces `app/views/controllers/observations/show/namings/_footer_buttons.erb`
# and inlines `observation_naming_buttons` + `suggest_namings_link`.
class Views::Controllers::Observations::Show::Namings::FooterButtons < Views::Base
  prop :user, ::User
  prop :obs, ::Observation

  def view_template
    div(class: "row") do
      div(class: "col-sm-11") do
        div(class: "row") do
          div(class: "col col-md-4") { render_buttons }
          div(class: "col col-md-8") { render_consensus_help }
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

    br
    render_suggest_button
  end

  # Text-button variant of the propose-naming link (the icon-only
  # variant lives in the panel `Header` for mobile). Strips the
  # `icon: :add` that `Tab::Naming::New.html_options` carries by
  # default — this button is text-only on `sm+`. ModalLink's
  # `tab:` shortcut takes name/path/opts from the tab as a unit
  # and doesn't expose a "merge an override" hook, so destructure
  # the tab manually here to merge `icon: nil` over its
  # html_options.
  def render_propose_button
    title, path, opts = propose_naming_tab.to_a
    render(Components::Link::Modal.new(
             "obs_#{@obs.id}_naming", title, path, **opts, icon: nil
           ))
  end

  def propose_naming_tab
    ::Tab::Naming::New.new(
      observation_id: @obs.id,
      text: :show_namings_propose_new_name.t,
      context: "namings_table",
      btn_class: "btn btn-default btn-sm d-none d-sm-inline-block"
    )
  end

  # Gating mirrors the legacy helper: a thumb image must exist (so
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
    button(
      type: :button,
      class: "btn btn-default btn-sm mt-2",
      data: suggest_button_data
    ) { plain(:show_namings_suggest_names.l) }
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
  # segment matches what the legacy helper sent.
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

  def render_consensus_help
    div(class: "card-text small") do
      trusted_html(:show_namings_consensus_help.t)
    end
  end
end
