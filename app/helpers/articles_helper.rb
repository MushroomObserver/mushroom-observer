# frozen_string_literal: true

module ArticlesHelper
  def articles_index_sorts
    [
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t],
      ["user",        :sort_by_user.t],
      ["title",       :sort_by_title.t]
    ].freeze
  end
end
