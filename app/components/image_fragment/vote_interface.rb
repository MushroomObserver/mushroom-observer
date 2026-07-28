# frozen_string_literal: true

# Image vote interface component for displaying image voting UI.
#
# Renders a vote meter (progress bar) and vote buttons for users to
# vote on images.
# The component handles:
# - Vote percentage calculation and display
# - Progress bar visualization
# - Vote buttons for all vote values
# - Current user's vote display
#
# @example Thumbnail hover overlay (default -- matrix box, InteractiveImage)
#   ImageFragment(type: :vote_interface, user: @user, image: @image,
#                 votes: true)
#
# @example Lightbox caption (always visible, no hover ancestor, and a
# second live copy can coexist in the DOM alongside the in-page one)
#   ImageFragment(type: :vote_interface, user: @user, image: @image,
#                 votes: true, context: :lightbox)
class Components::ImageFragment::VoteInterface < Components::Base
  prop :user, _Nilable(::User)
  prop :image, ::Image
  prop :votes, _Boolean, default: true
  # Where this is being rendered -- two independent concerns hang off
  # it, deliberately not conflated:
  #
  # Styling: `:overlay` (the default) gets the absolutely positioned,
  # hover-revealed treatment (`.vote-section`, see mo/_images.scss)
  # meant for sitting on top of a thumbnail inside an `.image-sizer`
  # ancestor (InteractiveImage/matrix-box). `:lightbox` gets the same
  # dark background/link colors via `.vote-section-lightbox`, minus
  # the absolute positioning -- always visible, not hover-revealed.
  # Any other context falls back to `.vote-section-inline`, which has
  # no styling yet -- a future non-lightbox inline caller (the image
  # show page has been mentioned) that isn't designed yet.
  #
  # Element ids: only `:lightbox` gets every id this component emits
  # (`vote_html_id`) prefixed. That's not a styling concern -- it's
  # because the lightbox is the one context where a *second* live copy
  # of the same image's vote UI can end up in the DOM simultaneously
  # (opening the lightbox injects its caption's copy alongside the
  # original in-page one), which would otherwise collide on id. A
  # future inline-but-not-lightbox context with only ever one copy on
  # the page doesn't need the prefix. `Images::VotesController#update`'s
  # turbo-stream response updates both the plain and `lightbox_`-
  # prefixed ids after a vote so both copies stay in sync.
  prop :context, Symbol, default: :overlay

  # The root element's own id -- also what a lazy-loading Turbo Frame
  # wrapper (see #4895) must be given so Turbo can find and swap this
  # component's response out of it. Single source of truth for both
  # `#vote_html_id("image_vote")` below and any external caller that
  # needs the id before the component itself has rendered.
  def self.frame_id(image_id:, context: :overlay)
    prefix = context == :lightbox ? "lightbox_" : ""
    "#{prefix}image_vote_#{image_id}"
  end

  def view_template
    return unless @votes && @image

    div(
      class: section_classes,
      id: vote_html_id("image_vote")
    ) do
      render_vote_meter_and_links
    end
  end

  private

  def section_classes
    class_names(
      case @context
      when :overlay then "vote-section"
      when :lightbox then "vote-section-lightbox"
      else "vote-section-inline"
      end,
      "require-user"
    )
  end

  def vote_html_id(base)
    return self.class.frame_id(image_id: @image.id, context: @context) if
      base == "image_vote"

    prefix = @context == :lightbox ? "lightbox_" : ""
    "#{prefix}#{base}_#{@image.id}"
  end

  def render_vote_meter_and_links
    vote_pct = calculate_vote_percentage

    render_vote_meter(vote_pct)
    render_vote_buttons(vote_pct)
  end

  def calculate_vote_percentage
    if @image.vote_cache
      ((@image.vote_cache / ::Image.all_votes.length) * 100).floor
    else
      0
    end
  end

  def render_vote_meter(vote_percentage)
    return unless vote_percentage

    div(
      class: "vote-meter progress",
      title: "#{@image.num_votes} #{:votes.ti}"
    ) do
      div(
        class: "progress-bar",
        id: vote_html_id("vote_meter_bar"),
        style: "width: #{vote_percentage}%"
      )
    end
  end

  def render_vote_buttons(vote_percentage)
    div(class: "vote-buttons mt-2") do
      div(
        class: "image-vote-links",
        id: vote_html_id("image_vote_links")
      ) do
        div(class: "text-center small") do
          render_user_vote_link
          render_image_vote_links
        end

        span(
          class: "hidden data_container",
          data: {
            id: @image.id,
            percentage: vote_percentage.to_s
          }
        )
      end
    end
  end

  def render_user_vote_link
    return unless @user && @image.users_vote(@user).present?

    render_vote_link(0)
    whitespace
  end

  def render_image_vote_links
    ::Image.all_votes.each_with_index do |vote, index|
      plain("|") if index.positive?
      render_vote_link(vote)
    end
  end

  def render_vote_link(vote)
    current_vote = @image.users_vote(@user)

    if current_vote == vote
      render_current_vote(vote)
    else
      render_vote_button(vote)
    end
  end

  def render_current_vote(vote)
    span(class: "image-vote") { image_vote_as_short_string(vote) }
  end

  def render_vote_button(vote)
    vote_text = vote.zero? ? "(x)" : image_vote_as_short_string(vote)

    Button(
      type: :put,
      variant: :strip,
      name: vote_text,
      class: "image-vote-link",
      target: image_vote_path(image_id: @image.id, value: vote),
      title: image_vote_as_help_string(vote),
      data: { image_id: @image.id, value: vote }
    )
  end
end
