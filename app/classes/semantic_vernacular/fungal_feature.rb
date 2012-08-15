# encoding: utf-8
#
#  = Fungal Feature
#
#  This class describes the data model for the class FungalFeature, a subclass 
#  of SemanticVernacularDataSource. An instance of FungalFeature class 
#  represents a fungal feature included in a VernacularFeatureDescription
#  instance.
#
#  == Class Methods
#  === Public
#  index::                    List all the available instances.
#  === Private
#  query_features_all::       Build a SPARQL query for the method "index".
#
#  == Instance Methods
#  ==== Public
#  get_domain::               Get the domain of an instance.
#  get_range::                Get the range of an instance.
#  ==== Private
#  query_attibutes::          Build a SPARQL query for getting attributes of an
#                             instance.
#  query_domain::             Build a SPARQL query for the method "get_domain".
#  query_range::              Build a SPARQL query for the method "get_range".
#
################################################################################

class FungalFeature < SemanticVernacularDataSource

  attr_accessor :uri,
                :label,
                :description,
                :reference,
                :domain,
                :range

  def initialize(uri)
    @uri = uri
    feature = self.class.query(query_attributes)[0]
    @label = feature["label"]["value"]
    @description = 
      feature["description"] == nil ? nil : feature["description"]["value"]
    @reference = 
      feature["reference"] == nil ? nil : feature["reference"]["value"]
    @domain = get_domain
    @range = get_range
  end

  def self.index
    query(query_features_all)
  end

  def get_domain
    domain = Hash.new
    attributes = self.class.query(query_domain)
    if attributes.length == 1 && attributes[0]["f"] == nil
      domain["base"] = attributes[0]["domain"]["value"]
    else
      attributes = attributes.select {|attribute| attribute["f"] != nil}
      domain["base"] = attributes[0]["domain"]["value"]
      attributes.each do |attribute|
        key = {
          "uri" => attribute["f"]["value"], 
          "label" => attribute["feature"]["value"]
        }
        value = {
          "uri" => attribute["v"]["value"],
          "label" => attribute["value"]["value"]
        }
        unless domain.has_key?(key) 
          domain[key] = Array.new
        end
        domain[key].push(value)
      end
    end
    return domain
  end

  def get_range
    range = Array.new
    self.class.query(query_range).each do |value|
      hash = {
        "uri" => value["uri"]["value"],
        "label" => value["label"]["value"]
      }
      range.push(hash)
    end
    return range
  end

  private

  def self.query_features_all
    QUERY_PREFIX +
    %(SELECT DISTINCT ?uri ?label
      FROM NAMED <#{SVF_GRAPH}>
      WHERE {
        ?uri rdfs:subPropertyOf+ svf:hasFungalFeature .
        ?uri rdfs:label ?label . })
  end

  def query_attributes
    QUERY_PREFIX +
    %(SELECT DISTINCT ?label ?description ?reference
      FROM NAMED <#{SVF_GRAPH}>
      WHERE {
        <#{@uri}> rdfs:subPropertyOf+ svf:hasFungalFeature .
        <#{@uri}> rdfs:label ?label . 
        OPTIONAL { <#{@uri}> dcterms:description ?description . }
        OPTIONAL { <#{@uri}> dcterms:references ?ref . 
                   ?ref rdfs:label ?reference . }})
  end

  def query_domain
    QUERY_PREFIX +
    %(SELECT DISTINCT ?domain ?f ?v ?feature ?value
      FROM NAMED <#{SVF_GRAPH}>
      WHERE {
        <#{@uri}> rdfs:subPropertyOf+ svf:hasFungalFeature .
        { <#{@uri}> rdfs:domain ?d . } UNION
        { <#{@uri}> rdfs:domain ?c1 .
          ?c1 owl:intersectionOf ?c2 .
          ?c2 rdf:first ?d .
          { ?c2 rdf:rest*/rdf:first ?c3 . } UNION
          { ?c2 rdf:rest*/rdf:first ?c4 .
            ?c4 owl:unionOf ?c5 . 
            ?c5 rdf:rest*/rdf:first ?c3 . }
          ?c3 owl:onProperty ?f . 
          ?c3 owl:someValuesFrom ?v .
          ?f rdfs:label ?feature . 
          ?v rdfs:label ?value . }
        ?d rdfs:label ?domain . })
  end

  def query_range
    QUERY_PREFIX +
    %(SELECT DISTINCT ?uri ?label
      WHERE {
        <#{@uri}> rdfs:subPropertyOf+ svf:hasFungalFeature .
        <#{@uri}> rdfs:range ?range . 
        ?range owl:equivalentClass ?c1 . 
        ?c1 owl:unionOf ?c2 . 
        ?c2 rdf:rest*/rdf:first ?c3 .
        ?uri rdfs:subClassOf* ?c3 . 
        ?uri owl:equivalentClass*/rdfs:label ?label . })
  end

end