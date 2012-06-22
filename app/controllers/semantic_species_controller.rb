# encoding: utf-8
#
#  = Semantic Species Controller
#
#  == Actions
#  index::  	List all available semantic species.
#  show::   	Show a specific species with uri, lable, properties, and links to 
#  						external websites.
#
################################################################################

class SemanticSpeciesController < ApplicationController
  def index 
  	@all = SemanticSpecies.index
  end
  
  def show
  	@species = SemanticSpecies.new(URI.unescape(params[:uri]))
  end
end