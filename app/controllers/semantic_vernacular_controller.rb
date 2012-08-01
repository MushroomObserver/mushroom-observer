# encoding: utf-8
#
#  = Semantic Vernacular Controller
#
#  == Actions
#  index::            List all semantic vernacular descriptions.
#  show::             Show a specific vernacular description with uri, lable, 
#                     features, and associated taxa.
#  create::           Create an instance of semantic vernacular descriptions.
#
################################################################################

require_dependency 'classes/semantic_vernacular'

class SemanticVernacularController < ApplicationController

  def index
  	@svds_with_name = SemanticVernacularDescription.index_with_name
    @svds_without_name = SemanticVernacularDescription.index_without_name
  end

  def show
  	@svd = SemanticVernacularDescription.new(URI.unescape(params[:uri]))
    if @svd.definition
      definition_features = SemanticVernacularDescription.get_features(
        @svd.definition["uri"]["value"])
      @definition_features = SemanticVernacularDescription.refactor_features(
        definition_features)
    end
    if @svd.description_proposals.length > 0
      @svd.description_proposals.each do |description|
        description_features = SemanticVernacularDescription.get_features(
          description["uri"]["value"])
        description["features"] = 
          SemanticVernacularDescription.refactor_features(description_features)
      end
    end
  end

  def create
    if params[:uri] && params[:desc]
      @svd = SemanticVernacularDescription.new(URI.unescape(params[:uri]))
      base_description = URI.unescape(params[:desc])
      base_features = 
        SemanticVernacularDescription.get_features(base_description)
      @base_features = 
        SemanticVernacularDescription.refactor_features(base_features)
    elsif params[:uri] && !params[:desc]
       @svd = SemanticVernacularDescription.new(URI.unescape(params[:uri]))
    elsif !params[:uri] && params[:desc]
      base_features = 
        SemanticVernacularDescription.get_features(URI.unescape(params[:desc]))
      @base_features = 
        SemanticVernacularDescription.refactor_features(base_features)
    end
  end

  def propose
    post_json = ActiveSupport::JSON.decode(params["data"])
    fill_IDs(post_json)
    fill_URIs(post_json)
    Rails.logger.debug(post_json)
    response = insert(post_json)
    Rails.logger.debug(response)
    respond_to do |format|
      format.json do
        render :json => { 
          :page_uri => post_json["svd"]["uri"],
          :status => response.class.name, 
          :message => response.message,
          :body => response.body,
          :value => response.value
        }.to_json
      end        
    end
  end

  def delete
    type = URI.unescape(params["type"])
    uri = URI.unescape(params["uri"])
    response = delete(type, uri)
    Rails.logger.debug(response)
    respond_to do |format|
      format.html {redirect_to :back}
    end
  end

  def accept
    type = URI.unescape(params["type"])
    uri = URI.unescape(params["uri"])
    response = insert_delete(type, uri)
    Rails.logger.debug(response)
    respond_to do |format|
      format.html {redirect_to :back}
    end
  end

  # Fill IDs into the received post data.
  def fill_IDs(data)
    if data["svd"]["uri"]
      data["svd"]["is_new"] = false
      data["label"]["is_name"] = false
      data["description"]["is_definition"] = false
    else
      data["svd"]["id"] = allocate_ID("SemanticVernacularDescription")
      data["svd"]["is_new"] = true
      data["label"]["is_name"] = false
      data["description"]["is_definition"] = false
    end
    if data["label"]["value"]
      data["label"]["id"] = allocate_ID("VernacularLabel")
    end
    if data["features"].length > 0
      data["description"]["id"] = allocate_ID("VernacularFeatureDescription")
    end
    if data["scientific_names"].length > 0
      id = allocate_ID("ScientificName")
      data["scientific_names"].each do |name| 
        name["id"] = id
        id = id + 1
      end
    end
    Rails.logger.debug(data)
  end

  # Allocate an ID to an individual resource by quering the triple store.
  def allocate_ID(type)
    SemanticVernacularDataSource.ask_max_ID(type)[0]["id"]["value"].to_i + 1
  end

  # Fill URIs into the received post data.
  def fill_URIs(data)
    if data["svd"]["id"] 
      data["svd"]["uri"] = SemanticVernacularDataSource.id_to_uri(
        data["svd"]["id"], "SemanticVernacularDescription")
    end
    if data["label"]["id"]
      data["label"]["uri"] = SemanticVernacularDataSource.id_to_uri(
        data["label"]["id"], "VernacularLabel")
    end
    if data["description"]["id"]
      data["description"]["uri"] = SemanticVernacularDataSource.id_to_uri(
      data["description"]["id"], "VernacularFeatureDescription")
    end
    if data["scientific_names"].length > 0
      data["scientific_names"].each do |name|
        name["uri"] = SemanticVernacularDataSource.id_to_uri(
          name["id"], "ScientificName")
      end
    end
    Rails.logger.debug(data)
  end

  # Generate RDF in turtle based on the received post data, and insert them to
  # the triple store.
  def insert(data)
    if data["svd"]["is_new"] == true
      response = SemanticVernacularDataSource.insert_svd(data["svd"])
    end
    if data["label"]["value"]
      response = SemanticVernacularDataSource.insert_label(
        data["svd"], 
        data["label"],
        data["user"])
    end
    if data["description"]["uri"]
      response = SemanticVernacularDataSource.insert_description(
        data["svd"], 
        data["description"],
        data["features"],
        data["user"])
    end
    if data["scientific_names"].length > 0
      response = SemanticVernacularDataSource.insert_scientific_names(
        data["svd"], 
        data["scientific_names"])
    end
    return response
  end

  # Delete triples from the triple store.
  def delete(type, uri)
    case type
      when "VernacularLabel"
        response = SemanticVernacularDataSource.delete_label(uri)
      when "VernacularFeatureDescription"
        response = SemanticVernacularDataSource.delete_description(uri)
      when "ScientificName"
        response = SemanticVernacularDataSource.delete_scientific_name(uri)
    end
  end

  # Insert and delete triples in the same time to/from the triple store.
  def insert_delete(type, uri)

  end

end