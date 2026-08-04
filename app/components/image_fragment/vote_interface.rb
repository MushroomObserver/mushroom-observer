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
# @example Show-page / matrix-box carousel
#   ImageFragment(type: :vote_interface, user: @user, image: @image,
#                 votes: true, context: :carousel)
#
# @example Lightbox caption (a second live copy can coexist in the DOM
# alongside the in-page one)
#   ImageFragment(type: :vote_interface, user: @user, image: @image,
#                 votes: true, context: :lightbox)
class Components::ImageFragment::VoteInterface < Components::Base
  prop :user, _Nilable(::User)
  prop :image, ::Image
  prop :votes, _Boolean, default: true
  # Which surface this renders on -- governs styling class, tooltip
  # direction, and id prefixing. `:matrix`/`:carousel` are both
  # overlay-styled (`.vote-section`) but `:carousel` points tooltips
  # up: a carousel's tooltip opens right above the show-page's
  # thumbnail-indicator strip, which paints over a downward one.
  # `:lightbox` gets `.vote-section-lightbox` and is the only context
  # whose ids get `lightbox_`-prefixed, since it's the only one where
  # a second live copy can coexist in the DOM.
  prop :context, Symbol, default: :matrix

  # The root element's own id -- also what a lazy-loading Turbo Frame
  # wrapper (see #4895) must be given so Turbo can find and swap this
  # component's response out of it. Single source of truth for both
  # `#vote_html_id("image_vote")` below and any external caller that
  # needs the id before the component itself has rendered.
  def self.frame_id(image_id:, context: :matrix)
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
      when :matrix, :carousel then "vote-section"
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
      ButtonGroup(
        class: "vote-btn-group",
        id: vote_html_id("image_vote_links")
      ) do
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

  def render_user_vote_link
    return unless @user && @image.users_vote(@user).present?

    render_vote_link(0)
  end

  def render_image_vote_links
    ::Image.all_votes.each { |vote| render_vote_link(vote) }
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
    Button(
      tag: :span, variant: :strip, class: "image-vote active"
    ) { plain(image_vote_as_short_string(vote)) }
  end

  def render_vote_button(vote)
    Button(
      type: :put,
      variant: :strip,
      icon: (:x if vote.zero?),
      name: vote.zero? ? :clear.ti : image_vote_as_short_string(vote),
      class: "image-vote-link",
      target: image_vote_path(image_id: @image.id, value: vote),
      title: image_vote_as_help_string(vote),
      data: { image_id: @image.id, value: vote,
              placement: @context == :carousel ? "top" : "bottom",
              tooltip_container: tooltip_container }
    )
  end

  def tooltip_container
    case @context
    when :carousel then ".carousel-caption"
    when :lightbox then ".vote-section-lightbox"
    else ".vote-section"
    end
  end
end
