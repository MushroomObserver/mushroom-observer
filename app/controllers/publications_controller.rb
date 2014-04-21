class PublicationsController < ApplicationController
  before_filter :login_required, :except => [
    :index,
    :show
  ]

  before_filter :require_successful_user, :only => [
    :create
  ]

  # GET /publications
  # GET /publications.xml
  def index
    store_location
    @publications = Publication.find(:all, :order => 'full')
    @full_count = Publication.count
    @peer_count = Publication.find(:all, :conditions => "peer_reviewed = 1").count
    @mo_count = Publication.find(:all, :conditions => "mo_mentioned = 1").count

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @publications }
    end
  end

  # GET /publications/1
  # GET /publications/1.xml
  def show
    store_location
    @publication = Publication.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @publication }
    end
  end

  # GET /publications/new
  # GET /publications/new.xml
  def new
    @publication = Publication.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @publication }
    end
  end

  # GET /publications/1/edit
  def edit
    @publication = Publication.find(params[:id])
    unless can_edit?(@publication)
      redirect_to(publications_url)
    end
  end

  # POST /publications
  # POST /publications.xml
  def create
    @publication = Publication.new(params[:publication])
    respond_to do |format|
      if @publication.save
        flash[:notice] = :runtime_created_at.t(:type => 'publication')
        format.html { redirect_to(@publication) }
        format.xml  { render :xml => @publication, :status => :created, :location => @publication }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @publication.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /publications/1
  # PUT /publications/1.xml
  def update
    @publication = Publication.find(params[:id])
    if can_edit?(@publication)
      respond_to do |format|
        if @publication.update_attributes(params[:publication])
          flash[:notice] = :runtime_updated_at.t(:type => 'publication')
          format.html { redirect_to(@publication) }
          format.xml  { head :ok }
        else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @publication.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /publications/1
  # DELETE /publications/1.xml
  def destroy
    @publication = Publication.find(params[:id])
    if can_delete?(@publication)
      @publication.destroy

      respond_to do |format|
        format.html { redirect_to(publications_url) }
        format.xml  { head :ok }
      end
    else
      redirect_to(publications_url)
    end
  end
end
