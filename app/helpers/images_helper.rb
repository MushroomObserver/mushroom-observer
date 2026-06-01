# frozen_string_literal: true

module ImagesHelper
  def images_index_sorts
    [
      ["name",          :sort_by_name.t],
      ["original_name", :sort_by_filename.t],
      ["date",          :sort_by_date.t],
      ["user",          :sort_by_user.t],
      ["created_at",    :sort_by_posted.t],
      ["updated_at",    :sort_by_updated_at.t],
      ["confidence",    :sort_by_confidence.t],
      ["image_quality", :sort_by_image_quality.t],
      ["num_views",     :sort_by_num_views.t]
    ].freeze
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
