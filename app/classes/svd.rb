# encoding: utf-8
#
#  = Svd
#
#  A lighter version of a SemanticVernacularDescription just for reading.
#
#  == Class Methods
#  === Public
#  svds_with_name::					  List all instances with accepted names.
#  svds_without_name::  			List all instances without accepted names.
#
#  === Private
#  query_svds_all::						Build a SPARQL query to get all instances.
#  query_svds_with_names:: 		Build a SPARQL query to get all instances with
#  														names.
#  ==== Private
#  query_data:: 							Build a SPARQL query for getting the data.
#
################################################################################

require "semantic_vernacular/semantic_vernacular_data_source"
class Svd < SemanticVernacularDataSource

	attr_accessor :uri, :name, :definition # , :labels, :descriptions, :scientific_names

	def initialize(args)
	  @all = nil
	  if args.class == String
	    @uri = args
	    query_data
	  else
  		@uri = args["uri"] and args["uri"]["value"]
  		@name = args["name"] and args["name"]["value"]
  		@definition = args["definition"] and args["definition"]["value"]
  		# @labels = args[:labels]
  		# @descriptions = args[:descriptions]
  		# @scientific_names = args[:scientific_names]
  	end
	end

  def self.all_svds; svds = query(query_svd_base).collect {|row| Svd.new(row)}; end
  
  def self.query_svd_base
    QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?name ?definition
			FROM <#{SVF_GRAPH}>
			WHERE {
				?uri rdfs:subClassOf svf:SemanticVernacularDescription .
				OPTIONAL {
  				?uri rdfs:subClassOf ?c1 .
  				?c1 owl:onProperty svf:hasSVDName .
  				?c1 owl:hasValue ?vl .
  				?vl rdfs:label ?name .
  			}
  			OPTIONAL {
  				?uri rdfs:subClassOf ?c2 .
  				?c2 owl:onProperty svf:hasDefinition .
  				?c2 owl:someValuesFrom ?uri .
				}
			})
  end
  
  def self.svds_with_names; svds = query(query_svd_with_names).collect {|row| Svd.new(row)}; end
  
  def self.ignore_query_svd_base
    QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?name ?definition
			FROM <#{SVF_GRAPH}>
			WHERE {
				?uri rdfs:subClassOf svf:SemanticVernacularDescription .
				?uri rdfs:subClassOf ?c1 .
				?c1 owl:onProperty svf:hasSVDName .
				?c1 owl:hasValue ?vl .
				?vl rdfs:label ?name .
  			OPTIONAL {
  				?uri rdfs:subClassOf ?c2 .
  				?c2 owl:onProperty svf:hasDefinition .
  				?c2 owl:someValuesFrom ?uri .
				}
			})
  end

end