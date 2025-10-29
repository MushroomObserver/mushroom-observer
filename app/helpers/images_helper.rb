# frozen_string_literal: true

module ImagesHelper
  # Args for the InteractiveImage component on Images#show
  def image_show_args
    { size: :huge,
      image_link: "#",
      extra_classes: "huge-image",
      votes: false }
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
