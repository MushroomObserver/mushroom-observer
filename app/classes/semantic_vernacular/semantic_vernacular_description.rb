# encoding: utf-8
#
#  = Semantic Vernacular
#
#  This class is a subclass of the SemanticVernacularDataSource class. It 
#  describes the data model of semantic vernaculars.
#
#  == Class Methods
#  === Public
#  index::    										List all instances with hierarchy.
#  === Private
#  query_all:: 										Overridden method.
#  query_all_hierarchy:: 					Overridden method.
#
#  == Instance Methods
#  ==== Public
#  associate_species::  					Associate a vernacular to species.
#  ==== Private
#  query_properties:: 						Overridden method.
#  query_property_to_species::  	Build a query to get the associated species 
#  																for a given paire of property and values.
#
################################################################################

class SemanticVernacularDescription < SemanticVernacularDataSourceViaProxy
	
	def self.index
		# List all instances with hierarchy
		query(query_all_hierarchy)
	end

	# Return: array of hashes {"species" => speices}
	def associate_species
		species = Array.new
		refactor_properties.each do |property, values|
			species << self.class.query(query_property_to_species(property, values))
		end
	return species.inject(:&)
	end

	private
	
	def self.query_all
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?uri ?label
			WHERE { 
				?uri rdfs:subClassOf sv:FungusDescriptiveVernacular .
				?uri rdfs:label ?label .
			})
	end

	def self.query_all_hierarchy
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?uri ?label ?parent
			WHERE { 
			?uri rdfs:subClassOf+ sv:FungusDescriptiveVernacular .
			?uri rdfs:label ?label . 
			?uri rdfs:subClassOf ?parent .
			?parent rdfs:subClassOf+ sv:Fungus .
			})
	end

	def query_properties
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?property ?value
			WHERE {
			<#{@uri}> owl:equivalentClass ?class .
			?class owl:intersectionOf ?list . 
			{ ?list rdf:rest*/rdf:first ?member . } UNION
			{ ?list rdf:rest*/rdf:first ?m .
			  ?m owl:unionOf ?union .
				?union rdf:rest*/rdf:first ?member . }
			?member a owl:Restriction . 
			?member owl:onProperty ?p .
			?member owl:someValuesFrom ?v .
			?p rdfs:label ?property .
			?v rdfs:label ?value .
			})
	end

	def query_property_to_species(property, values)
		query = QUERY_PREFIX + 
		%(SELECT DISTINCT ?species
			WHERE {
				{ ?species rdfs:subClassOf ?class .
					?class owl:unionOf ?list . 
					?list rdf:rest*/rdf:first ?member . } UNION 
				{ ?species rdfs:subClassOf ?member }
				?member a owl:Restriction .
				?member owl:onProperty ?p .
				?member owl:someValuesFrom ?v .)
		q = Array.new
		values.each do |value|
			q << %({ ?p rdfs:label "#{property}"^^rdfs:Literal .
							 ?v rdfs:label "#{value}"^^rdfs:Literal . })
		end
		query << q.join(" UNION ") << "}"
	end
end