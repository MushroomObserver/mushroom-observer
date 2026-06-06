# frozen_string_literal: true

module CommentsHelper
  def comments_index_sorts
    [
      ["user",       :sort_by_user.t],
      ["created_at", :sort_by_posted.t],
      ["updated_at", :sort_by_updated_at.t]
    ].freeze
  end
end
