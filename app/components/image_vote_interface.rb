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
# @example
#   render Components::ImageVoteInterface.new(
#     user: @user,
#     image: @image,
#     votes: true
#   )
class Components::ImageVoteInterface < Components::Base
  prop :user, _Nilable(User)
  prop :image, ::Image
  prop :votes, _Boolean, default: true

  def view_template
    return unless @votes && @image

    div(
      class: "vote-section require-user",
      id: "image_vote_#{@image.id}"
    ) do
      render_vote_meter_and_links
    end
  end

  private

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
      title: "#{@image.num_votes} #{:Votes.t}"
    ) do
      div(
        class: "progress-bar",
        id: "vote_meter_bar_#{@image.id}",
        style: "width: #{vote_percentage}%"
      )
    end
  end

  def render_vote_buttons(vote_percentage)
    div(class: "vote-buttons mt-2") do
      div(
        class: "image-vote-links",
        id: "image_vote_links_#{@image.id}"
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

    put_button(
      name: vote_text,
      class: "image-vote-link",
      path: image_vote_path(image_id: @image.id, value: vote),
      title: image_vote_as_help_string(vote),
      data: { image_id: @image.id, value: vote }
    )
  end
end
