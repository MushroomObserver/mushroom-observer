# encoding: utf-8
#
#  = Semantic Vernacular Controller
#
#  == Actions
#  index::            List all semantic vernacular descriptions.
#  index_species::  	List all semantic species.
#  show::             Show a specific vernacular description with uri, lable, 
#                     features, and associated taxa.
#  show_species::   	Show a specific species with uri, lable, features, and
# 										linked external websites.
#  create::           Create an instance of semantic vernacular descriptions.
#
################################################################################

require_dependency 'classes/semantic_vernacular'

class SemanticVernacularController < ApplicationController

  def index
  	@all_vernaculars = SemanticVernacularDescription.index
  end

  def index_species
  	@all_species = SemanticSpecies.index
  end
  
  def show
  	@vernacular = SemanticVernacularDescription.new(URI.unescape(params[:uri]))
  end

  def show_species
  	@species = SemanticSpecies.new(URI.unescape(params[:uri]))
  end

  def create
    @all_features = SemanticFungalFeature.index
  end

end