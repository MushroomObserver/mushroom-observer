# encoding: utf-8
#
#  = Semantic Vernacular Controller
#
#  == Actions
#
#  index::            List all available semantic vernaculars with hierarchy.
#  show::             Show a specific vernacular with uri, lable and features.
#
################################################################################

class SemanticVernacularController < ApplicationController
  def index 
  	@vernaculars = SemanticVernacularDataSourceViaProxy.index
  end
  
  def show
  	@vernacular = SemanticVernacularDataSourceViaProxy.new(URI.unescape(params[:uri]))
  end
end