# frozen_string_literal: true

# Control information about publications that benefit from or cite MO
class PublicationsController < ApplicationController
  before_action :login_required, except: [:index, :show]
  before_action :require_successful_user, only: [:create]
  before_action :store_location, only: [:index, :show]

  # GET /publications
  # GET /publications.xml
  def index
    respond_to do |format|
      format.html { build_index_with_query }
      format.xml  { render(xml: Publication.order(:full).to_a) }
    end
  end

  # Read by `add_sorter` in the view. Each key must resolve to
  # `Publication.order_by_<key>`.
  def index_sort_options
    [
      ["name",       :sort_by_name.t],
      ["created_at", :sort_by_created_at.t],
      ["updated_at", :sort_by_updated_at.t],
      ["user",       :sort_by_user.t]
    ].freeze
  end

  # GET /publications/1
  # GET /publications/1.xml
  def show
    @publication = Publication.find(params[:id])
    respond_to do |format|
      format.html do
        render(Views::Controllers::Publications::Show.new(
                 publication: @publication
               ))
      end
      format.xml { render(xml: @publication) }
    end
  end

  # GET /publications/new
  # GET /publications/new.xml
  def new
    @publication = Publication.new
    respond_to do |format|
      format.html { render_new_view }
      format.xml  { render(xml: @publication) }
    end
  end

  # GET /publications/1/edit
  def edit
    @publication = Publication.find(params[:id])
    if can_edit?(@publication)
      render_edit_view
    else
      redirect_to(publications_url)
    end
  end

  # POST /publications
  # POST /publications.xml
  def create
    params = permitted_publication_params.merge(user: @user)
    @publication = Publication.new(params)
    respond_to do |format|
      if @publication.save
        flash_notice(:runtime_created_at.t(type: :publication))
        format.html { redirect_to(@publication) }
        format.xml  do
          render(xml: @publication, status: :created,
                 location: @publication)
        end
      else
        flash_object_errors(@publication)
        format.html { render_new_view_invalid }
        format.xml  do
          render(xml: { errors: @publication.formatted_errors },
                 status: :unprocessable_content)
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
        format.html { redirect_to(publications_url) }
        format.xml  do
          render(xml: "can't edit", status: :unprocessable_content)
        end
      elsif @publication.update(permitted_publication_params)
        flash_notice(:runtime_updated_at.t(type: :publication))
        format.html { redirect_to(@publication) }
        format.xml  { head(:ok) }
      else
        flash_object_errors(@publication)
        format.html { render_edit_view_invalid }
        format.xml  do
          render(xml: { errors: @publication.formatted_errors },
                 status: :unprocessable_content)
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
        format.html { redirect_to(publications_url) }
        format.xml  { head(:ok) }
      else
        format.html { redirect_to(publications_url) }
        format.xml  do
          render(xml: "can't delete",
                 status: :unprocessable_content)
        end
      end
    end
  end

  ##############################################################################

  private

  def index_display_opts(opts, _query)
    { num_per_page: 50, include: :user }.merge(opts)
  end

  def permitted_publication_params
    if params[:publication]
      params[:publication].permit(:full, :link, :how_helped, :mo_mentioned,
                                  :peer_reviewed)
    else
      {}
    end
  end

  def render_index_view
    render(Views::Controllers::Publications::Index.new(
             query: @query, pagination_data: @pagination_data,
             objects: @objects
           ))
  end

  def render_new_view
    render(Views::Controllers::Publications::New.new(
             publication: @publication
           ))
  end

  def render_edit_view
    render(Views::Controllers::Publications::Edit.new(
             publication: @publication
           ))
  end
end
