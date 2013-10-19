# encoding: utf-8
#
#  = Semantic Vernacular Controller
#
#  == Actions
#  index::            List all Semantic Vernacular Descriptions (SVDs).
#  show::             Show a specific SVD.
#  create::           Create an instance of SVDs either from scratch or based on
#                     an existing feature description.
#  propose::          Respond to the HTTP POST request for creating a proposal.
#  delete::           Delete a name, a description, or an associated scientific
#                     name.
#  accept::           Accept a proposal as the formal name or definition.
#  index_features::   List all available features.
#  show_feature::     Show a sepecific feature.
#
################################################################################

require_dependency 'classes/semantic_vernacular'

class SemanticVernacularController < ApplicationController
  before_filter :login_required
  
  def index
  	@svds_with_name = SemanticVernacularDescription.index_with_name
    @svds_without_name = SemanticVernacularDescription.index_without_name
  end

  def show
  	@svd = SemanticVernacularDescription.new(URI.unescape(params[:uri]))
  end

  def create
    if params[:uri] && params[:desc]
      @svd = SemanticVernacularDescription.new(URI.unescape(params[:uri]))
      @base_description = VernacularFeatureDescription.new(
        URI.unescape(params[:desc]))
    elsif params[:uri] && !params[:desc]
       @svd = SemanticVernacularDescription.new(URI.unescape(params[:uri]))
    elsif !params[:uri] && params[:desc]
      @base_description = VernacularFeatureDescription.new(
        URI.unescape(params[:desc]))
    end
  end

  def propose
    post_json = ActiveSupport::JSON.decode(params["data"])
    fill_IDs(post_json)
    fill_URIs(post_json)
    Rails.logger.debug(post_json)
    response = triple_store_insert(post_json)
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
    if is_in_admin_mode? # Probably should be expanded to any MO user
      type = URI.unescape(params["type"])
      uri = URI.unescape(params["uri"])
      response = triple_store_delete(type, uri)
      Rails.logger.debug(response)
      respond_to do |format|
        format.html {redirect_to :back}
      end
    else
      flash_error(:delete_svd_not_allowed.l)
      redirect_to(:action => 'index')
    end
  end

  def accept
    type = URI.unescape(params["type"])
    uri = URI.unescape(params["uri"])
    response = triple_store_modify(type, uri)
    Rails.logger.debug(response)
    respond_to do |format|
      format.html {redirect_to :back}
    end
  end

  def index_features
    @features = FungalFeature.index
  end

  def show_feature
    @feature = FungalFeature.new(params["uri"])
  end


  ##############################################################################
  # Helper methods
  ##############################################################################

  # Fill IDs into the received post data.
  def fill_IDs(data)
    id = allocate_ID
    if data["svd"]["uri"]
      data["svd"]["is_new"] = false
    else
      data["svd"]["id"] = id
      data["svd"]["is_new"] = true
      id = id + 1
    end
    if data["label"]["value"]
      data["label"]["id"] = id
      id = id + 1
    end
    if data["features"].length > 0
      data["description"]["id"] = id
      id = id + 1
    end
    if data["scientific_names"].length > 0
      data["scientific_names"].each do |name| 
        name["id"] = id
        id = id + 1
      end
    end
    Rails.logger.debug(data)
  end

  # Allocate an ID to an individual resource by quering the current maximum ID
  # in the triple store.
  def allocate_ID
    SemanticVernacularDataSource.ask_max_ID[0]["id"]["value"].to_i + 1
  end

  # Fill URIs into the received post data based on the IDs acollated to them.
  def fill_URIs(data)
    if data["svd"]["id"] 
      data["svd"]["uri"] = SemanticVernacularDataSource.id_to_uri(
        data["svd"]["id"])
    end
    if data["label"]["id"]
      data["label"]["uri"] = SemanticVernacularDataSource.id_to_uri(
        data["label"]["id"])
    end
    if data["description"]["id"]
      data["description"]["uri"] = SemanticVernacularDataSource.id_to_uri(
      data["description"]["id"])
    end
    if data["scientific_names"].length > 0
      data["scientific_names"].each do |name|
        name["uri"] = SemanticVernacularDataSource.id_to_uri(
          name["id"])
      end
    end
    Rails.logger.debug(data)
  end

  # Generate RDF in .ttl based on the received post data, and insert them to
  # the triple store.
  def triple_store_insert(data)
    if data["svd"]["is_new"] == true
      response = SemanticVernacularDescription.insert(data["svd"])
    end
    if data["label"]["value"]
      response = VernacularLabel.insert(
        data["svd"], 
        data["label"],
        data["user"])
    end
    if data["description"]["uri"]
      response = VernacularFeatureDescription.insert(
        data["svd"], 
        data["description"],
        data["features"],
        data["user"])
    end
    if data["scientific_names"].length > 0
      response = ScientificName.insert(
        data["svd"], 
        data["scientific_names"])
    end
    return response
  end

  # Delete triples from the triple store.
  def triple_store_delete(type, uri)
    type.constantize.delete(uri)
  end

  # Modify triples in the triple store.
  def triple_store_modify(type, uri)
    type.constantize.modify(uri)
  end

end