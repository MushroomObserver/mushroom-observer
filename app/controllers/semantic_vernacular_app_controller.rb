# encoding: utf-8
#
#  = Semantic Vernacular App Controller
#
#  == Actions
#  index_vernaculars::  List all available semantic vernaculars with hierarchy.
#  index_species::  		List all available semantic species.
#  show_vernacular::   	Show a specific vernacular with uri, lable, properties, 
#  											and associated species.
#  show_species::   		Show a specific species with uri, lable, properties, and
# 										  linked external websites.
#
################################################################################

require_dependency 'classes/semantic_vernacular_app'

class SemanticVernacularAppController < ApplicationController
  def index_vernaculars
  	@all_vernaculars = SemanticVernacular.index
  end

  def index_species
  	@all_species = SemanticSpecies.index
  end
  
  def show_vernacular
  	@vernacular = SemanticVernacular.new(URI.unescape(params[:uri]))
  end

  def show_species
  	@species = SemanticSpecies.new(URI.unescape(params[:uri]))
  end
end