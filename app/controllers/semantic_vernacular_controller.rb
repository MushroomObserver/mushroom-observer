# encoding: utf-8
#
#  = Semantic Vernacular Controller
#
#  == Actions
#  index::  	List all available semantic vernaculars with hierarchy.
#  show::   	Show a specific vernacular with uri, lable, properties, and 
# 						associated species.
#
################################################################################

class SemanticVernacularController < ApplicationController
  def index 
  	@all = SemanticVernacular.index
  end
  
  def show
  	@vernacular = SemanticVernacular.new(URI.unescape(params[:uri]))
  end
end