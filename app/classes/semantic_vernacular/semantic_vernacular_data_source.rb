# encoding: utf-8
#
#  = Semantic Vernacular Data Source
#
#  This class describes the abstract data model for the semantic vernacular
#  module. Subclasses should override some of the methods to implement 
#  corresponding functionalities. Data are retrieved directly through a triple 
#  store.
#
#  == Class Methods
#  === Public
#  index::    						List all instances.
#  === Private
#  query:: 								Submit a query to the triple store and get responses.
#  query_all:: 						Build a query to get all instances.
#
#  == Instance Methods
#  ==== Public
#  to_s::           			Returns the lable for a given instance.
#  get_label::						Returns the lable for a given instance.
#  
#  ==== Private
#  query_label:: 					Build a query to get the lable for a given instance.
#
################################################################################

require "sparql/client"

class SemanticVernacularDataSource

	attr_accessor :uri, :label

	def initialize(uri)
		@uri = uri # String
		@label = get_label # String
	end

	def self.index
		query(query_all)
	end

	def to_s
		@label
	end

	# Return: string
	def get_label
		self.class.query(query_label)[0]["label"].to_s
	end

	private
	
	ENDPOINT = "http://leo.tw.rpi.edu:2058/sparql"
	
	# Retrun: array of hashes
	# [{"key_1" => "value_1"}, {"key_2" => "value_2"}, ...]
	def self.query(query)
		sparql = SPARQL::Client.new(ENDPOINT)
  	response = sparql.query(query) # RDF::Query::Solution
  end

  # Prefix for all SPARQL queries.
	QUERY_PREFIX = 
		%(PREFIX owl: <http://www.w3.org/2002/07/owl#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX sv: <http://aquarius.tw.rpi.edu/ontology/fungi.owl#>\n)

	def self.query_all
	end

	def query_label
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?label
			WHERE {
				<#{@uri}> rdfs:label ?label .
			})
	end
	
end