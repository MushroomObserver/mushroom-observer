# encoding: utf-8
#
#  = Vernacular Feature Description
#
#  This class describes the data model for the class 
#  VernacularFeatureDescription, a subclass of SemanticVernacularDataSource. An 
#  instance of VernacularFeatureDescription class represents either a defintion 
#  or a definition proposal for an SVD instance.
#
#  == Class Methods
#  === Public
#  insert::                   Overrdie the parent class method.
#  delete::                   Inherit the parent class method.
#  modify::                   Inherit the parent class method.
#  === Private
#  insert_triples::           Overrdie the parent class method.
#  delete_triples::           Override the parent class method.
#  modify_triples::           Override the parent class method.
#  insert_features_triples::  A helf method for the method "insert_triples".
#
#  == Instance Methods
#  ==== Public
#  get_features::             Get all the features included in an instance.
#  refactor_features::        Refactor the return of the method "get_features"
#                             into a hash.
#  ==== Private
#  query_attibutes::          Build a SPARQL query for getting attributes of an
#                             instance.
#  query_features::           Build a SPAQL query for the method "get_features".
#
################################################################################

class VernacularFeatureDescription < SemanticVernacularDataSource

  attr_accessor :uri,
                :creator,
                :created_date_time,
                :features

  def initialize(uri)
    @uri = uri
    desc = self.class.query(query_attributes)[0]
    @creator = SVUser.new(desc["user"]["value"])
    @created_date_time = desc["dateTime"]["value"]
    @features = refactor_features
  end

  def self.insert(svd, description, features, user)
    update(insert_triples(svd, description, features, user))
  end

  def get_features
    self.class.query(query_features)
  end

  def refactor_features
    refactoring = Hash.new
    get_features.each do |feature|
      key = {
        "uri" => feature["f"]["value"], 
        "label" => feature["feature"]["value"]
      }
      value = {
        "uri" => feature["v"]["value"], 
        "label" => feature["value"]["value"]
      }
      unless refactoring.has_key?(key) 
        refactoring[key] = Array.new
      end
      refactoring[key].push(value)
    end
    return refactoring
  end

  private

  def query_attributes
    QUERY_PREFIX +
    %(SELECT DISTINCT ?user ?dateTime
      FROM NAMED <#{SVF_GRAPH}>
      WHERE {
        <#{@uri}> rdfs:subClassOf svf:VernacularFeatureDescription .
        <#{@uri}> rdfs:subClassOf ?c1 .
        ?c1 owl:onProperty svf:proposedBy .
        ?c1 owl:hasValue ?user .
        <#{@uri}> rdfs:subClassOf ?c2 .
        ?c2 owl:onProperty svf:proposedAt .
        ?c2 owl:hasValue ?dateTime . })
  end

  def query_features
    QUERY_PREFIX +
    %(SELECT DISTINCT ?f ?v ?feature ?value
      FROM NAMED <#{SVF_GRAPH}>
      WHERE {
        <#{@uri}> rdfs:subClassOf+ svf:VernacularFeatureDescription .
        <#{@uri}> owl:equivalentClass ?c1 .
        ?c1 owl:intersectionOf ?c2 . 
        { ?c2 rdf:rest*/rdf:first ?c3 . } UNION
        { ?c2 rdf:rest*/rdf:first ?c4 .
          ?c4 owl:unionOf ?c5 .
          ?c5 rdf:rest*/rdf:first ?c3 . }
        ?c3 owl:onProperty ?f .
        ?c3 owl:someValuesFrom ?v .
        ?f rdfs:subPropertyOf+ svf:hasFungalFeature .
        ?f rdfs:label ?feature .
        ?v rdfs:label ?value . })
  end

  def self.insert_triples(svd, description, features, user)
    QUERY_PREFIX +
    %(INSERT DATA {
        GRAPH <#{SVF_GRAPH}> {
          <#{svd["uri"]}> 
            rdfs:subClassOf
              #{insert_some_object_values_from_restriction_triples(
                SVF_NAMESPACE + "hasDescription", description["uri"])} .
          <#{description["uri"]}>
            a owl:class;
            rdfs:subClassOf svf:VernacularFeatureDescription;
            rdfs:subClassOf
              #{insert_has_object_value_restriction_triples(
                SVF_NAMESPACE + "proposedBy", user["uri"])};
            rdfs:subClassOf
              #{insert_has_datatype_value_restriction_triples(
                SVF_NAMESPACE + "proposedAt", 
                Time.now.strftime("%FT%T%:z"), 
                "xsd:dateTime")};
            svf:hasID "#{description["id"]}"^^xsd:positiveInteger;
            #{insert_features_triples(features)} . }})      
  end

  def self.delete_triples(description)
    QUERY_PREFIX +
    %(WITH <#{SVF_GRAPH}>
      DELETE {
        ?svd rdfs:subClassOf ?c . 
        ?c ?p1 ?o1 . 
        <#{description}> ?p2 ?o2 .
        ?o3 ?p4 ?o4 .
        ?list ?p6 ?o6 .
        ?z rdf:first ?head .
        ?z rdf:rest ?tail .
        ?head ?p7 ?o7 . }
      WHERE {
        ?svd rdfs:subClassOf ?c .
        ?c owl:someValuesFrom <#{description}> .
        ?c ?p1 ?o1 .
        <#{description}> ?p2 ?o2 .
        <#{description}> ?p3 ?o3 .
        ?o3 ?p4 ?o4 .
        <#{description}> owl:equivalentClass ?o5 .
        ?o5 owl:intersectionOf ?list .
        ?list ?p6 ?o6 .
        ?list rdf:rest* ?z .
        ?z rdf:first ?head .
        ?head ?p7 ?o7 .
        ?z rdf:rest ?tail .
        FILTER isBlank(?o3) . })
  end

  def self.modify_triples(uri)
    QUERY_PREFIX +
    %(WITH <#{SVF_GRAPH}>
      DELETE { 
        ?c1 owl:onProperty svf:hasDescription .
        ?c2 owl:onProperty svf:hasDefinition . }
      INSERT { 
        ?c1 owl:onProperty svf:hasDefinition .
        ?c2 owl:onProperty svf:hasDescription . }
      WHERE {
        ?svd rdfs:subClassOf svf:SemanticVernacularDescription .
        ?svd rdfs:subClassOf ?c1 .
        ?c1 owl:onProperty svf:hasDescription . 
        ?c1 owl:someValuesFrom <#{uri}> .
        OPTIONAL { ?svd rdfs:subClassOf ?c2 .
        ?c2 owl:onProperty svf:hasDefinition . 
        ?c2 owl:someValuesFrom ?name . }})
  end

  def self.insert_features_triples(features)
    rdf = %(owl:equivalentClass
              [ a owl:class;
              owl:intersectionOf \(svf:Fungus )
    features.each do |feature|
      if feature["values"].length > 1
        rdf << %([ a owl:class;
                   owl:unionOf \()
        feature["values"].each do |value|
          rdf << insert_some_object_values_from_restriction_triples(
            feature["feature"], value)
        end
        rdf << %(\)])
      end
      if feature["values"].length == 1
        rdf << insert_some_object_values_from_restriction_triples(
          feature["feature"], feature["values"][0])
      end
    end
    rdf << %(\)])
  end

end