# encoding: utf-8
#
#  = Vernacular Label
#
#  This class describes the data model for the class VernacularLabel, a subclass
#  of SemanticVernacularDataSource. An instance of VernacularLabel class 
#  represents either a name or a name proposal for an SVD instance.
#
#  == Class Methods
#  === Public
#  insert::  									Overrdie the parent class method.
#  delete:: 									Inherit the parent class method.
#  modify:: 									Inherit the parent class method.
#  === Private
#  insert_triples:: 					Overrdie the parent class method.
#  delete_triples::  					Override the parent class method.
#  modify_triples::  					Override the parent class method.
#
#  == Instance Methods
#  ==== Private
#  query_attibutes::  				Build a SPARQL query for getting attributes of an
# 														instance.
#
################################################################################

class VernacularLabel < SemanticVernacularDataSource

	attr_accessor :uri,
								:label,
								:creator,
								:created_date_time

	def initialize(uri)
		@uri = uri
		vl = self.class.query(query_attributes)[0]
		@label = vl["label"]["value"]
		@creator = SVUser.new(vl["user"]["value"])
		@created_date_time = vl["dateTime"]["value"]
	end

	def self.insert(svd, label, user)
		update(insert_triples(svd, label, user))
	end

	private

	def query_attributes
		QUERY_PREFIX +
		%(SELECT DISTINCT ?label ?user ?dateTime
			FROM <#{SVF_GRAPH}>
			WHERE {
				<#{@uri}> a svf:VernacularLabel .
				<#{@uri}> rdfs:label ?label .
				<#{@uri}> svf:proposedBy ?user .
				<#{@uri}> svf:proposedAt ?dateTime . })
	end
	
	def self.insert_triples(svd, label, user)
		QUERY_PREFIX +
		%(INSERT DATA {
				GRAPH <#{SVF_GRAPH}> {
				<#{svd["uri"]}> 
					rdfs:subClassOf
						#{insert_has_object_value_restriction_triples(
							SVF_NAMESPACE + "hasLabel", label["uri"])} . 
				<#{label["uri"]}>
					a owl:NamedIndividual, svf:VernacularLabel;
					rdfs:label "#{label["value"]}"^^rdfs:Literal;
					svf:hasID "#{label["id"]}"^^xsd:integer;
					svf:proposedAt "#{Time.now.strftime("%FT%T%:z")}"^^xsd:dateTime;
					svf:proposedBy <#{user["uri"]}> . }})
	end

	def self.delete_triples(label)
		QUERY_PREFIX +
		%(DELETE WHERE {
				GRAPH <#{SVF_GRAPH}> {
					?svd rdfs:subClassOf ?c .
					?c owl:hasValue <#{label}> .
					?c ?p1 ?o1 .
					<#{label}> ?p2 ?o2 . }})
	end

	def self.modify_triples(uri)
		QUERY_PREFIX +
		%(WITH <#{SVF_GRAPH}>
			DELETE { 
				?c1 owl:onProperty svf:hasLabel .
				?c2 owl:onProperty svf:hasSVDName . }
			INSERT { 
				?c1 owl:onProperty svf:hasSVDName .
				?c2 owl:onProperty svf:hasLabel . 
				}
			WHERE {
				?svd rdfs:subClassOf svf:SemanticVernacularDescription .
				?svd rdfs:subClassOf ?c1 .
				?c1 owl:onProperty svf:hasLabel . 
				?c1 owl:hasValue <#{uri}> .
				OPTIONAL { ?svd rdfs:subClassOf ?c2 .
				?c2 owl:onProperty svf:hasSVDName . 
				?c2 owl:hasValue ?name . }})
	end

end