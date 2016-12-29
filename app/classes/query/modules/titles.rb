module Query::Modules::Titles
  attr_accessor :title_tag
  attr_accessor :title_args

  def initialize_title
    @title_tag = "query_title_#{flavor}".to_sym
    @title_args = { type: model.to_s.underscore.to_sym }
  end

  def title
    initialize_query unless initialized?
    @title_tag.t(params.merge(@title_args))
  end
end
