module Query::Modules::Titles
  attr_accessor :title_args

  def initialize_title
    @title_args = params.merge(
      tag: "query_title_#{flavor}".to_sym,
      type: model.to_s.underscore.to_sym
    )
    for line in params[:title] || []
      fail "Invalid syntax in :title parameter: '#{line}'" if line !~ / /
      @title_args[$`.to_sym] = $'
    end
  end

  def title
    initialize_query unless initialized?
    @title_args[:raw] || @title_args[:tag].to_sym.t(@title_args)
  end
end
