module Query::All
  def add_sort_order_to_title
    if params[:by]
      by = :"sort_by_#{params[:by]}"
      title_args[:tag] ||= :query_title_all_by
      title_args[:order] = by.t
    end
  end
end
