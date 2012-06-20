# encoding: utf-8
#
#  = Semantic Vernacular Data Source
#
#  This class describes Semantic Vernacular data model. Relative data are retrieved directly through
#  a triple store.
#
#  == Class Methods
#  === Public
#  index::    										Returns all the available vernaculars with hierarchy.
#  === Private
#  query:: 												Submit a query and get responses.
#  query_all_vernaculars:: 				Build a query to get all the available vernaculars.
#  query_vernacular_hierarchy:: 	Build a query to get all the available vernacualrs with hierarchy.
#
#  == Instance Methods
#  ==== Public
#  to_s::           							Returns the label of a semantic vernacular instance.
#  uri_to_label::									Returns the lable for a given uri.
#  uri_to_properites:: 						Returns the features for a given uri
#  ==== Private
#  build_query_uri_to_label:: 		Build a query to get the lable for a given uri.
#  query_uri_to_properties:: 			Build a query to get the features for a given uri.
#
################################################################################

class SemanticVernacularDataSource
	attr_accessor :uri, :label, :features

	def initialize(uri)
		@uri = uri
		@label = uri_to_label(uri)
		@features = uri_to_properties(uri)
	end

	def self.index
		#query(query_all_vernaculars)
		query(query_vernacular_hierarchy)
	end

	def to_s
		@label
	end

	def uri_to_label(uri)
		self.class.query(query_uri_to_label(uri))[0]["label"]
	end

	def uri_to_properties(uri)
		self.class.query(query_uri_to_properties(uri))
	end

	private
	
	ENDPOINT = "http://aquarius.tw.rpi.edu:2024/sparql"
	
	# Retrun value is in the format of
	# [{key => value}, {key => value}, ... ]
	def self.query(query)
		sparql = SPARQL::Client.new(ENDPOINT)
  	response = sparql.query(query)
  end

	QUERY_PREFIX = 
		%(PREFIX owl: <http://www.w3.org/2002/07/owl#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX sv: <http://aquarius.tw.rpi.edu/ontology/mushroom.owl#>)

	def self.query_all_vernaculars
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?uri ?label
			WHERE { 
				?uri rdfs:subClassOf sv:FungusDescriptiveVernacular .
				?uri rdfs:label ?label .
			})
	end

	def self.query_vernacular_hierarchy
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?label ?parent
			WHERE { 
			?uri rdfs:subClassOf+ sv:FungusDescriptiveVernacular .
			?uri rdfs:label ?label . 
			?uri rdfs:subClassOf ?parent .
			?parent rdfs:subClassOf+ sv:Fungus .
			})
	end

	def query_uri_to_label(uri)
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?label
			WHERE {
				<#{uri}> rdfs:label ?label .
			})
	end

	def query_uri_to_properties(uri)
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?feature ?value
			WHERE {
			<#{uri}> owl:equivalentClass ?class .
			?class owl:intersectionOf ?list . 
			{ ?list rdf:rest*/rdf:first ?member . } UNION
			{ ?list rdf:rest*/rdf:first ?m .
			  ?m owl:unionOf ?union .
				?union rdf:rest*/rdf:first ?member . }
			?member a owl:Restriction . 
			?member owl:onProperty ?f .
			?f rdfs:label ?feature .
			?member owl:someValuesFrom ?v .
			?v rdfs:label ?value .
			})
	end
	
end