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
    ].compact)
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

  # The lightbox caption is a real, hidden DOM element now (see
  # Components::Image::Base#render_lightbox_caption, #4894) -- a plain
  # `update` swaps its content directly, same as any other Turbo
  # target. `update`, not `replace`, so the wrapping
  # `#lightbox_caption_<id>.lightbox-caption.d-none` element itself
  # (lightGallery's selector target) survives the swap.
  def lightbox_caption_stream
    return unless @obs.thumb_image

    turbo_stream.update(
      "lightbox_caption_#{@obs.thumb_image.id}",
      Components::ImageFragment.new(
        type: :lightbox_caption,
        user: @user, obs: @obs, identify: true,
        observation_view: @observation_view,
        # Same thumb image the matrix-box theater button opens the
        # lightbox on -- without it, LightboxCaption's @image is nil,
        # so the original/EXIF links break (empty /images//original)
        # and the vote section (gated on @image) silently disappears
        # from the refreshed caption.
        image: @obs.thumb_image
      )
    )
  end
end
