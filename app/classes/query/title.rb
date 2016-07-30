module Query::Title
  def initialize_title
    self.title_args = params.merge(
      tag: "query_title_#{flavor}".to_sym,
      type: model_string.underscore.to_sym
    )
    if args = params[:title]
      for line in args
        fail "Invalid syntax in :title parameter: '#{line}'" if line !~ / /
        title_args[$`.to_sym] = $'
      end
    end
  end

  def title
    initialize_query unless initialized?
    if raw = title_args[:raw]
      raw
    else
      title_args[:tag].to_sym.t(title_args)
    end
  end
end
