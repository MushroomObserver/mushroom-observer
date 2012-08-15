# encoding: utf-8
#
#  = SV User
#
#  This class describes the data model for the class SVUser, a subclass of 
#  SemanticVernacularDataSource. An instance of SVUser class represents a user
#  in the Semantic Vernacular System.
#
#  == Instance Methods
#  ==== Private
#  query_attibutes::          Build a SPARQL query for getting attributes of an
#                             instance.
#
################################################################################

class SVUser < SemanticVernacularDataSource

  attr_accessor :uri,
                :name,
                :email

  def initialize(uri)
    @uri = uri
    user = self.class.query(query_attributes)[0]
    @name = user["name"]["value"]
    @email = user["email"]["value"]
  end

  private

  def query_attributes
    QUERY_PREFIX +
    %(SELECT DISTINCT ?name ?email
      FROM NAMED <#{SVF_GRAPH}>
      WHERE {
        <#{@uri}> a svf:User .
        <#{@uri}> svf:hasName ?name .
        <#{@uri}> svf:hasEmail ?email . })
  end

end