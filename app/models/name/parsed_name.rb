# frozen_string_literal: true

# parsing a string to a Name
module Name::ParsedName
  attr_accessor :text_name, :search_name, :sort_name, :display_name
  attr_accessor :rank, :author, :parent_name

  def initialize(params)
    @text_name = params[:text_name]
    @search_name = params[:search_name]
    @sort_name = params[:sort_name]
    @display_name = params[:display_name]
    @parent_name = params[:parent_name]
    @rank = params[:rank]
    @author = params[:author]
  end

  def real_text_name
    Name.display_to_real_text(self)
  end

  def real_search_name
    Name.display_to_real_search(self)
  end

  # Values required to create/modify attributes of Name instance.
  def params
    {
      text_name: @text_name,
      search_name: @search_name,
      sort_name: @sort_name,
      display_name: @display_name,
      author: @author,
      rank: @rank
    }
  end

  def inspect
    params.merge(parent_name: @parent_name).inspect
  end
end
