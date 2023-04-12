# frozen_string_literal: true

module ImageVotesHelper
  # used in shared/image_thumbnail
  def vote_section_html(votes, image)
    return "" unless votes && image && User.current

    content_tag(:div, "", class: "vote-section") do
      render(partial: "shared/image_vote_links",
             locals: { image: image })
    end
  end

  # Create an image link vote, where vote param is vote number ie: 3
  # Returns a form input button if the user has NOT voted this way
  # JS is listening to any element with [data-role="image_vote"],
  # Even though this is not an <a> tag, but an <input>, it's ok.
  def image_vote_link(image, vote)
    current_vote = image.users_vote(User.current)
    vote_text = if vote.zero?
                  image_vote_none.html_safe
                else
                  image_vote_as_short_string(vote)
                end

    if current_vote == vote
      return content_tag(:span, image_vote_as_short_string(vote),
                         class: "image-vote")
    end

    put_button(name: vote_text, remote: true,
               class: "image-vote-link",
               path: image_vote_path(image_id: image.id, value: vote),
               title: image_vote_as_help_string(vote),
               data: { role: "image_vote", image_id: image.id, value: vote })
  end

  def image_vote_none
    icon("fa-regular", "circle-xmark", class: "fa-sm")
  end

  # image vote lookup used in show_image
  def find_list_of_votes(image)
    image.image_votes.sort_by do |v|
      (v.anonymous ? :anonymous.l : v.user.unique_text_name).downcase
    rescue StandardError
      "?"
    end
  end
end
