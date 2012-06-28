# encoding: utf-8
#
#  = Semantic Fungal Feature (SFF)
#
#  This class is a subclass of the SemanticVernacularDataSource class. It 
#  describes the data model of semantic fungal features.
#
#  == Class Methods
#  === Public
#  index (inherited)::        List all SFF instances.
#  === Private
#  query (inherited)::        Submit a SPARQL query and get responses.
#  query_all::                Build a query to get all SFF instances.
#
#  == Instance Methods
#  ==== Public
#  to_s (inherited)::         Returns the lable for a given SFF instance.
#  get_label (inherited)::    Returns the lable for a given SFF instance.
#  get_values::               Returns the values for a given SFF instance.
#  
#  ==== Private
#  query_label (inherited)::  Build a query to get the lable for a given SFF
#                             instance.
#  query_values::             Build a query to get the values for a given SFF
#                             instance.
#
################################################################################

class SemanticFungalFeature < SemanticVernacularDataSource

  def get_values
    self.class.query(query_values)
  end

  private

  def self.query_all
    QUERY_PREFIX + 
    %(SELECT DISTINCT ?uri ?label ?parent
      WHERE { 
      ?uri rdfs:subPropertyOf+ sv:hasFeature .
      ?uri rdfs:label ?label . 
      ?uri rdfs:subPropertyOf ?parent .
      ?uri rdfs:subPropertyOf* sv:hasFeature .
      })
  end

  def query_values
    QUERY_PREFIX +
    %(SELECT DISTINCT ?uri ?label
      WHERE {
        <#{@uri}> rdfs:range ?range .
        ?range owl:equivalentClass ?class .
        ?class owl:unionOf ?list .
        ?list rdf:rest*/rdf:first ?uri .
        ?uri rdfs:label ?label .
      })
  end
  
end