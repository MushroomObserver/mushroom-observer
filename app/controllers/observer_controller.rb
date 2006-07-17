# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'find'
require 'ftools'

class ObserverController < ApplicationController
  before_filter :login_required, :except => (CSS + [:color_themes, :image, :images_by_title, :img_thumb,
                                                    :intro, :list_comments, :list_images, :list_observations,
                                                    :list_species_lists, :observations_by_name, :original_image,
                                                    :show_comment, :show_image, :show_observation, :show_original,
                                                    :show_species_list, :species_lists_by_title])
  # Default page
  def index
    list_observations
    render :action => 'list_observations'
  end

  def login
    list_observations
    render :action => 'list_observations'
  end

  # left-hand panel -> list_comments.rhtml
  def list_comments
    store_location
    @comment_pages, @comments = paginate(:comments,
                                     :order => "'created' desc",
                                     :per_page => 10)
  end

  # show_observation.rhtml -> add_comment.rhtml
  # I used the session for this based on the parallel case in one of the Rails tutorial.
  # It seems like I could just as easily do it with the params.  However, for 'save_comment'
  # I don't want an extra key for the observation since I'm using the params to create the
  # comment.
  def add_comment
    @comment = Comment.new
    @observation = session[:observation]
  end

  # show_observation.rhtml -> show_comment.rhtml
  def show_comment
    store_location
    @comment = Comment.find(params[:id])
  end

  # add_comment.rhtml -> save_comment -> add_comment.rhtml
  # Here's where params is used to create the comment and
  # the observation is recovered from session.
  def save_comment
    @comment = Comment.new(params[:comment])
    @comment.created = Time.now
    @observation = session[:observation]
    @comment.observation = @observation
    @comment.user = session['user']
    if @comment.save
      flash[:notice] = 'Comment was successfully added.'
      redirect_to(:action => 'show_observation', :id => @observation)
    else
      flash[:notice] = sprintf('Unable to save comment: %s', @comment.user)
      render :action => 'add_comment'
    end
  end
  
  # show_comment.rhtml -> edit_comment.rhtml
  def edit_comment
    @comment = Comment.find(params[:id])
    unless check_user_id(@comment.user_id)
      render :action => 'show_comment'
    end
  end

  # edit_comment.rhtml -> update_comment -> show_comment.rhtml
  def update_comment
    @comment = Comment.find(params[:id])
    if check_user_id(@comment.user_id) # Even though edit makes this check, avoid bad guys going directly
      if @comment.update_attributes(params[:comment])
        @comment.save
        flash[:notice] = 'Comment was successfully updated.'
        redirect_to :action => 'show_comment', :id => @comment
      else
        render :action => 'edit_comment'
      end
    else
      render :action => 'show_comment'
    end
  end

  # show_comment.rhtml -> destroy -> show_observation.rhtml
  def destroy_comment
    @comment = Comment.find(params[:id])
    if check_user_id(@comment.user_id)
      id = @comment.observation_id
      @comment.destroy
      redirect_to :action => 'show_observation', :id => id
    else
      render :action => 'show_comment'
    end
  end

  # left-hand panel -> list_observations.rhtml
  def list_observations
    store_location
    @observation_pages, @observations = paginate(:observations,
                                                 :order => "'when' desc",
                                                 :per_page => 10)
  end

  # observations_by_name.rhtml
  def observations_by_name
    store_location
    @observations = Observation.find(:all, :order => "'what' asc, 'when' desc")
  end

  # list_observations.rhtml -> show_observation.rhtml
  # Setup session to have the right observation.
  def show_observation
    store_location
    @observation = Observation.find(params[:id])
    session[:observation] = @observation
  end

  # left-hand panel -> new_observation.rhtml
  def new_observation
    @observation = Observation.new
    @observation.what = 'Unknown'
  end

  # new_observation.rhtml -> list_observations.rhtml
  def create_observation
    @observation = Observation.new(params[:observation])
    @observation.created = Time.now
    @observation.modified = @observation.created
    @observation.user = session['user']
    if @observation.save
      flash[:notice] = 'Observation was successfully created.'
      redirect_to :action => 'edit_observation', :id => @observation
    else
      render :action => 'new_observation'
    end
  end

  # list_observation.rhtml, show_observation.rhtml -> edit_observation.rhtml
  # Setup session to have the right observation.
  def edit_observation
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      session[:observation] = @observation
    else 
      render :action => 'show_observation'
    end
  end

  # edit_observation.rhtml -> show_observation.rhtml
  # Updates modified and saves changes
  def update_observation
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id) # Even though edit makes this check, avoid bad guys going directly
      if @observation.update_attributes(params[:observation])

        thumb = params[:thumbnail]
        if thumb
          thumb.each do |index, id|
            @observation.thumb_image_id = id
          end
        end

        # Why does this work and the following line doesn't?
        # Tested with 'obs_mod' rather than 'modified'.  Same effect.
        @observation.modified = Time.new
        # @observation.touch
        @observation.save

        flash[:notice] = 'Observation was successfully updated.'
        redirect_to :action => 'show_observation', :id => @observation
      else
        render :action => 'edit_observation'
      end
    else
      render :action => 'show_observation'
    end
  end

  # list_observations.rhtml -> destroy -> list_observations.rhtml
  def destroy_observation
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      lists = @observation.species_lists
      @observation.destroy
      # Check any species_lists to see if they are now empty.  If so destroy them.
      # Is there a better way to do this as part of the species_list model?
      for l in lists
        if l.observations.length == 0
          l.destroy
        end
      end
      redirect_to :action => 'list_observations'
    else
      render :action => 'show_observation'
    end
  end

  ## Image support

  # Various -> list_images.rhtml
  def list_images
    store_location
    @image_pages, @images = paginate(:images,
                                     :order => "'when' desc",
                                     :per_page => 10)
  end

  # images_by_title.rhtml
  def images_by_title
    store_location
    @images = Image.find(:all, :order => "'title' asc, 'when' desc")
  end

  # list_images -> show_image.rhtml
  # show_original.rhtml -> show_image.rhtml
  # Thumbnails should hook up to this
  def show_image
    store_location
    @image = Image.find(params[:id])
  end

  # show_image.rhtml -> show_original.rhtml
  def show_original
    store_location
    @image = Image.find(params[:id])
  end

  # list_images.rhtml, show_image.rhtml -> edit_image.rhtml
  def edit_image
    @image = Image.find(params[:id])
    unless check_user_id(@image.user_id)
      render :action => 'show_image'
    end
  end

  # edit_image.rhtml -> update_image -> show_image.rhtml
  def update_image
    @image = Image.find(params[:id])
    if check_user_id(@image.user_id) # Even though edit makes this check, avoid bad guys going directly
      if @image.update_attributes(params[:image])
        @image.modified = Time.now
        @image.save
        flash[:notice] = 'Image was successfully updated.'
        redirect_to :action => 'show_image', :id => @image
      else
        render :action => 'edit_image'
      end
    else
      render :action => 'show_image'
    end
  end

  # list_images.rhtml -> list_images.rhtml
  # Should this be allowed?  How do we cleanup corresponding observations?
  def destroy_image
    @image = Image.find(params[:id])
    if check_user_id(@image.user_id)
      for observation in Observation.find(:all, :conditions => sprintf("thumb_image_id = '%s'", @image.id))
        observation.thumb_image_id = nil
        observation.save
      end
      @image.destroy
      redirect_to :action => 'list_images'
    else
      render :action => 'show_image'
    end
  end

  # show_observation.rhtml -> manage_images.rhtml
  def manage_images
    @observation = session[:observation]
    if check_user_id(@observation.user_id)
      @img = Image.new
    else
      render :action => 'show_observation'
    end
  end
  
  # manage_images.rhtml -> save_image -> manage_images.rhtml
  def save_image
    @observation = session[:observation]
    if check_user_id(@observation.user_id)
      # Upload image
      @img = Image.new(params[:image])
      @img.created = Time.now
      @img.modified = @img.created
      @img.user = session['user']
      if @img.save
        if @img.save_image
          @observation.add_image(@img)
          @observation.save
        else
          logger.error("Unable to save image")
          flash[:notice] = 'Invalid image'
        end
      end
    
      # Or reuse image by id
      @observation.add_image_by_id(params[:observation][:idstr].to_i)
      redirect_to(:action => 'manage_images', :id => @observation)
    
      # Or delete images
      images = params[:selected]
      if images
        images.each do |image_id, do_it|
          if do_it == 'yes'
            @observation.remove_image_by_id(image_id)
          end
        end
      end
    else
      render :action => 'show_observation'
    end
  end

  # image loader
  # edit_image.rhtml, show_image.rhtml
  def image
    @img = Image.find(params[:id])
    send_data(@img.get_image,
              :filename => @img.title,
              :type => @img.content_type,
              :disposition => "inline")
  end

  # original image loader
  # show_original.rhtml
  def original_image
    @img = Image.find(params[:id])
    send_data(@img.get_original,
              :filename => @img.title,
              :type => @img.content_type,
              :disposition => "inline")
  end

  # thumbnail loader
  # list_images.rhtml, (select_images.rhtml)
  def img_thumb
    @img = Image.find(params[:id])
    send_data(@img.get_thumbnail,
              :filename => @img.title,
              :type => @img.content_type,
              :disposition => "inline")
  end


  # left-hand panel -> new_species_list.rhtml
  def new_species_list
    @species_list = SpeciesList.new
  end

  def create_species_list
    args = params[:species_list]
    now = Time.now
    args["created"] = now
    args["modified"] = now
    args["user"] = session['user']
    @species_list = SpeciesList.new(args)

    if @species_list.save
      flash[:notice] = 'Species list was successfully created.'
      redirect_to :action => 'list_observations'
      species = args["species"]
      args.delete("species")
      args.delete("title")
      for s in species
        species_name = s.strip()
        if species_name != ''
          args["what"] = species_name
          obs = Observation.new(args)
          obs.save
          @species_list.observations << obs
        end
      end
    else
      render :action => 'new_species_list'
    end
  end

  # list_species_list.rhtml & notes links -> show_species_list.rhtml
  # Use session to store the current species list since this parallels
  # the usage for show_observation.
  def show_species_list
    store_location
    @species_list = SpeciesList.find(params[:id])
    session[:species_list] = @species_list
  end

  # Needs both a species_list and an observation.
  def remove_observation_from_species_list
    species_list = SpeciesList.find(params[:species_list])
    if check_user_id(species_list.user_id)
      observation = Observation.find(params[:observation])
      species_list.modified = Time.now
      species_list.observations.delete(observation)
      # Check to see if the species_list is empty.  If so, destroy it.
      if species_list.observations.length == 0 # Is there a good way to move this behavior into the species_list model?
        flash[:notice] = 'Deleted empty species list'
        species_list.destroy
      end
      redirect_to :action => 'manage_species_lists', :id => observation
    end
  end

  # Needs both a species_list and an observation.
  def add_observation_to_species_list
    species_list = SpeciesList.find(params[:species_list])
    if check_user_id(species_list.user_id)
      observation = Observation.find(params[:observation])
      species_list.modified = Time.now
      species_list.observations << observation
      redirect_to :action => 'manage_species_lists', :id => observation
    end
  end
  
  # left-hand panel -> list_species_lists.rhtml
  def list_species_lists
    store_location
    @species_list_pages, @species_lists = paginate(:species_lists,
                                                   :order => "'when' desc",
                                                   :per_page => 10)
  end

  # list_species_lists.rhtml -> destroy -> list_species_lists.rhtml
  def destroy_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id)
      @species_list.destroy
      redirect_to :action => 'list_species_list'
    else
      render :action => 'show_species_list'
    end
  end

  # species_lists_by_title.rhtml
  def species_lists_by_title
    store_location
    @species_lists = SpeciesList.find(:all, :order => "'what' asc, 'when' desc")
  end

  # list_species_list.rhtml, show_species_list.rhtml -> edit_species_list.rhtml
  # Setup session to have the right species_list.
  def edit_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id)
      session[:species_list] = @species_list
    else 
      render :action => 'show_species_list'
    end
  end

  # edit_species_list.rhtml -> show_species_list.rhtml
  # Updates modified and saves changes
  def update_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id) # Even though edit makes this check, avoid bad guys going directly
      if @species_list.update_attributes(params[:species_list])
        @species_list.modified = Time.new
        @species_list.save

        flash[:notice] = 'Species List was successfully updated.'
        redirect_to :action => 'show_species_list', :id => @species_list
      else
        render :action => 'edit_species_list'
      end
    else
      render :action => 'show_species_list'
    end
  end

  # show_observation.rhtml -> manage_species_lists.rhtml
  def manage_species_lists
    @observation = session[:observation]
  end

  helper_method :check_permission
  def check_permission(user_id)
    !session['user'].nil? && ((user_id == session['user'].id) || (session['user'].id == 0))
  end

  protected

  def check_user_id(user_id)
    result = check_permission(user_id)
    unless result
      flash[:notice] = 'Permission denied.'
    end
    result
  end

  # Look in obs_extras.rb for code for uploading directory trees of images.
end
