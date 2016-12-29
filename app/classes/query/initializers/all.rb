module Query::Initializers::All
  def add_sort_order_to_title
    if params[:by]
      self.title_tag = :query_title_all_by
      title_args[:order] = :"sort_by_#{params[:by]}"
    end
  end
end
