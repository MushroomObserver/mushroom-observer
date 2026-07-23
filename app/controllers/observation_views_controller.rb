# frozen_string_literal: true

class ObservationViewsController < ApplicationController
  before_action :login_required

  # endpoint to mark an observation as 'reviewed' by the current user
  # Note that it doesn't take an ov.id param - it looks up or creates an ov
  # from an observation_id param (confusingly, :id!) and the current user
  def update
    # basic sanitizing of the param. ivars needed in js response
    # checked is a string! Superform nests under observation_view
    @reviewed = params.dig(:observation_view, :reviewed) == "1"
    return unless (obs = Observation.find(params[:id]))

    # update_view_stats creates an o_v if it doesn't exist, returns the record
    @obs_id = obs.id # ivar used in the js template
    @obs = obs # needed for lightbox caption rendering
    @observation_view = ObservationView.update_view_stats(@obs_id,
                                                          @user.id,
                                                          @reviewed)

    respond_to do |format|
      format.turbo_stream { render_update_streams }
      format.html do
        return redirect_to(identify_observations_path)
      end
    end
  end

  private

  def render_update_streams
    render(turbo_stream: [
             caption_toggle_stream,
             box_toggle_stream,
             lightbox_caption_stream
           ])
  end

  def caption_toggle_stream
    turbo_stream.replace(
      "caption_reviewed_toggle_#{@obs_id}",
      Components::ObservationFragment.new(
        type: :mark_as_reviewed_toggle,
        observation_view: @observation_view,
        selector: "caption_reviewed"
      )
    )
  end

  def box_toggle_stream
    turbo_stream.replace(
      "box_reviewed_toggle_#{@obs_id}",
      Components::ObservationFragment.new(
        type: :mark_as_reviewed_toggle,
        observation_view: @observation_view,
        selector: "box_reviewed",
        label_class: "stretched-link"
      )
    )
  end

  # `<turbo-stream action="update_lightbox_caption" obs-id="…">` is a
  # custom Turbo Stream action (handled by the lightbox Stimulus
  # controller). Build it via Rails' `tag` builder so `@obs_id` is
  # attribute-escaped — passing strings straight into a heredoc is
  # an XSS shape even when `@obs_id` happens to be an integer today.
  def lightbox_caption_stream
    caption = view_context.capture do
      view_context.render(
        Components::ImageFragment.new(
          type: :lightbox_caption,
          user: @user, obs: @obs, identify: true,
          observation_view: @observation_view
        )
      )
    end
    view_context.tag.turbo_stream(
      view_context.tag.template { caption },
      action: "update_lightbox_caption",
      "obs-id": @obs_id
    )
  end
end
