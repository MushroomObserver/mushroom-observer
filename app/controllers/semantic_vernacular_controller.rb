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
  	@all = SemanticVernacularDescription.index
  end

  def show
  	@svd = SemanticVernacularDescription.new(URI.unescape(params[:uri]))
  end

  def create
    if params[:uri]
      @svd = SemanticVernacularDescription.new(URI.unescape(params[:uri]))
    end
  end

  def submit
    post_json = ActiveSupport::JSON.decode(params["data"])
    fill_IDs(post_json)
    fill_URIs(post_json)
    Rails.logger.debug(post_json.inspect)
    response = update_triple_store(post_json)
    respond_to do |format|
      format.json do
        render :json => { 
          :status => response.class.name, 
          :message => response.message,
          :body => response.body,
          :value => response.value
        }.to_json
      end        
    end
  end

  # Fill IDs into the received post data.
  def fill_IDs(data)
    unless data["svd"]["uri"]
      data["svd"]["id"] = allocate_ID("SemanticVernacularDescription")
    end
    if data["label"]
      data["label"]["id"] = allocate_ID("VernacularLabel")
    end
    if data["features"].length > 0
      data["definition"]["id"] = allocate_ID("VernacularDefinition")
    end
    if data["scientific_names"].length > 0
      id = allocate_ID("ScientificName")
      data["scientific_names"].each do |name| 
        name["id"] = id
        id = id + 1
      end
    end
  end

  # Allocate an ID to an individual resource by quering the triple store.
  def allocate_ID(type)
    Rails.logger.debug(type)
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
    if data["definition"]["id"]
      data["definition"]["uri"] = SemanticVernacularDataSource.id_to_uri(
      data["definition"]["id"], "VernacularDefinition")
    end
    if data["scientific_names"].length > 0
      data["scientific_names"].each do |name|
        name["uri"] = SemanticVernacularDataSource.id_to_uri(
          name["id"], "ScientificName")
      end
    end
  end

  # Generate RDF in turtle based on the received post data.
  def update_triple_store(data)
    if data["label"]
      response = SemanticVernacularDataSource.insert_label(
        data["svd"], 
        data["label"],
        {"uri"=>"http://mushroomobserver.org/svf.owl#U2"})
    end
  end

  # def test
  #   data = {
  #     "svd"=>{
  #       "id"=>nil, 
  #       "uri"=>"http://mushroomobserver.org/svf.owl#SVD1"
  #     }, 
  #     "label"=>{
  #       "id"=>nil, 
  #       "uri"=>nil, 
  #       "value"=>"ReallyFakeLabel"
  #     }, 
  #     "definition"=>{
  #       "id"=>nil, 
  #       "uri"=>nil
  #     }, 
  #     "features"=>[], 
  #     "scientific_names"=>[], 
  #     "svds"=>[]
  #   }
  #   fill_IDs(data)
  #   Rails.logger.debug(data)
  #   fill_URIs(data)
  #   Rails.logger.debug(data)
  #   @res = update_triple_store(data)
  #   #@res = SemanticVernacularDataSource.test_query2
  #   #Rails.logger.debug(@res)
  #   #@res = SemanticVernacularDataSource.test
  #   Rails.logger.debug(@res)
  # end
  
end