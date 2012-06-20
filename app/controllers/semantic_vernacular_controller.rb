class SemanticVernacularController < ApplicationController
  def index 
  	@vernaculars = SemanticVernacularDataSourceViaProxy.index
  end
  
  def show
  	@vernacular = SemanticVernacularDataSourceViaProxy.new(URI.unescape(params[:uri]))
  end
end