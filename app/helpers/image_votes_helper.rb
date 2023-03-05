# frozen_string_literal: true

# image vote lookup used in show_image
module ImageVotesHelper
  # moved from the ImagesController
  def find_list_of_votes(image)
    image.image_votes.sort_by do |v|
      (v.anonymous ? :anonymous.l : v.user.unique_text_name).downcase
    rescue StandardError
      "?"
    end
  end
end
