# encoding: utf-8
#
#  = Semantic Species
#
#  This class is a subclass of the SemanticVernacularDataSource class. It 
#  describes the data model of semantic species.
#
#  == Class Methods
#  === Public
#  index::  								List all instances.
#  === Private
#  query_all:: 							Overridden method.
#  query_all_hierarchy:: 		Overridden method.
#
#  == Instance Methods
#  ==== Public
#  associate_species::  		Associate a vernacular to species.
#  ==== Private
#  query_properties:: 			Overridden method.
#  query_links::  					Build a query to get links to external websites for
#  													a given species instance.
#
################################################################################

class SemanticSpecies < SemanticVernacularDataSourceViaProxy

	def self.index
		# List all instances in a flat structure
		query(query_all)
	end

	# Return: array of hashes
	# [{"link" => "link_1", "url" => "url_1"}, 
	#  {"link" => "link_2", "url" => "url_2"}, ...]
	def get_links
		self.class.query(query_links)
	end

	private
	
	def self.query_all
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?uri ?label
			WHERE { 
				?uri rdfs:subClassOf sv:FungusSpecies .
				?uri rdfs:label ?label .
			})
	end

	def self.query_all_hierarchy
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?label ?parent
			WHERE { 
			?uri rdfs:subClassOf+ sv:FungusSpecies .
			?uri rdfs:label ?label . 
			?uri rdfs:subClassOf ?parent .
			?parent rdfs:subClassOf+ sv:Fungus .
			})
	end

	def query_properties
		QUERY_PREFIX +
		%(SELECT DISTINCT ?property ?value
			WHERE {
				{ <#{@uri}> rdfs:subClassOf ?class .
					?class owl:unionOf ?list .
					?list rdf:rest*/rdf:first ?member . } UNION
				{ <#{@uri}> rdfs:subClassOf ?member . }
				?member a owl:Restriction .
				?member owl:onProperty ?p .
				?member owl:someValuesFrom ?v .
				?p rdfs:label ?property .
				?v rdfs:label ?value .
			})
	end

	def query_links
		QUERY_PREFIX +
		%(SELECT DISTINCT ?link ?url
			WHERE {
				<#{@uri}> ?l ?url .
				?l rdfs:subPropertyOf rdfs:seeAlso .
				?l rdfs:label ?link .
			})
	end
end