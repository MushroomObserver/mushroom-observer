require 'sparql/client'

class SemanticVernacularController < ApplicationController
  def index 
  	sparql = SPARQL::Client.new('http://dbpedia.org/sparql')
  	@results = sparql.query('select distinct ?s where {?s ?p ?o} LIMIT 10')
  end
  
  def show
  	#uri = URI.escape(params[:uri])
  	#sparql = SPARQL::Client.new(SemanticVernacularHelper::ENDPOINT)
  	#@results = sparql.query(SemanticVernacularHelper::)
  end
end
