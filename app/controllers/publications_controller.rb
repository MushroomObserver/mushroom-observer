# frozen_string_literal: true

# CRUD lists of publications which benefitted from MO
class PublicationsController < ApplicationController
  before_action :login_required, except: [
    :index,
    :show
  ]

  before_action :require_successful_user, only: [
    :create
  ]

  # GET /publications
  # GET /publications.xml
  def index
    store_location
    @publications = Publication.all.order("full")
    @full_count = @publications.length
    @peer_count = @publications.count(&:peer_reviewed)
    @mo_count   = @publications.count(&:mo_mentioned)
    @title = :publication_index_title.l
    @navbar = index_navbar
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @publications }
    end
  end

  # GET /publications/1
  # GET /publications/1.xml
  def show
    store_location
    @publication = Publication.find(params[:id])
    @title = :show_publication_title.l
    @navbar = show_navbar
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @publication }
    end
  end

  # GET /publications/new
  # GET /publications/new.xml
  def new
    @publication = Publication.new
    @title = :create_publication_title.l
    @navbar = new_navbar
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @publication }
    end
  end

  # GET /publications/1/edit
  def edit
    @publication = Publication.find(params[:id])
    redirect_to publications_path unless can_edit?(@publication)
    @title = :edit_publication_title.l
    @navbar = edit_navbar
  end

  # POST /publications
  # POST /publications.xml
  def create
    params = whitelisted_publication_params.merge(user: User.current)
    @publication = Publication.new(params)
    respond_to do |format|
      if @publication.save
        flash_notice(:runtime_created_at.t(type: :publication))
        format.html { redirect_to publication_path(@publication.id) }
        format.xml  do
          render xml: @publication, status: :created,
                 location: @publication
        end
      else
        flash_object_errors(@publication)
        format.html { render action: :new }
        format.xml  do
          render xml: @publication.errors,
                 status: :unprocessable_entity
        end
      end
    end
  end

  # PUT /publications/1
  # PUT /publications/1.xml
  def update
    @publication = Publication.find(params[:id])
    respond_to do |format|
      if !can_edit?(@publication)
        format.html { redirect_to publications_path }
        format.xml  { render xml: "can't edit", status: :unprocessable_entity }
      elsif @publication.update(whitelisted_publication_params)
        flash_notice(:runtime_updated_at.t(type: :publication))
        format.html { redirect_to publication_path(@publication.id) }
        format.xml  { head :ok }
      else
        flash_object_errors(@publication)
        format.html { render action: :edit }
        format.xml  do
          render xml: @publication.errors,
                 status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /publications/1
  # DELETE /publications/1.xml
  def destroy
    @publication = Publication.find(params[:id])
    respond_to do |format|
      if can_delete?(@publication)
        @publication.destroy
        format.html { redirect_to publications_path }
        format.xml  { head :ok }
      else
        format.html { redirect_to publications_path }
        format.xml  do
          render xml: "can't delete",
                 status: :unprocessable_entity
        end
      end
    end
  end

  ##############################################################################

  private

  def init_navbar(links = nil)
    { title: { title: :PUBLICATIONS.t, url: publications_path },
      links: links }
  end

  def index_navbar
    init_navbar([{ title: :create_publication.t,
                   url: new_publication_path,
                   icon: "fa-plus" }])
  end

  def edit_navbar
    init_navbar([{ title: :cancel_and_show.t(type: :publication),
                   url: publication_path(@publication.id),
                   icon: "fa-backspace" }])
  end

  def new_navbar
    init_navbar([{ title: :cancel_and_show.t(type: :PUBLICATIONS),
                   url: publications_path,
                   icon: "fa-backspace" }])
  end

  def show_navbar
    links = [
      { title: :create_publication.t, url: new_publication_path,
        icon: "fa-plus" }
    ]
    if in_admin_mode? || @publication.can_edit?(@user)
      links << {
        title: :edit_object.t(type: :publication),
        url: edit_publication_path(id: @publication.id),
        icon: "fa-edit"
      }
      links << {
        title: :destroy_object.t(type: :publication),
        url: publication_path(id: @publication.id),
        method: :delete, data: { confirm: :are_you_sure.t },
        icon: "fa-trash-alt"
      }
    end
    init_navbar(links)
  end

  def whitelisted_publication_params
    if params[:publication]
      params[:publication].permit(:full, :link, :how_helped, :mo_mentioned,
                                  :peer_reviewed)
    else
      {}
    end
  end
end
