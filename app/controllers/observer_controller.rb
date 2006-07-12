# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'find'
require 'ftools'

class ObserverController < ApplicationController
  before_filter :login_required, :except => (CSS + [:color_themes, :image, :images_by_title, :img_thumb,
                                                    :intro, :list_images, :list_observations,
                                                    :observations_by_name, :original_image,
                                                    :show_comment, :show_image, :show_observation,:show_original])
  # Default page
  def index
    list_observations
    render :action => 'list_observations'
  end

  def login
    list_observations
    render :action => 'list_observations'
  end

  # Various -> list_comments.rhtml
  def list_comments
    store_location
    @comment_pages, @comments = paginate(:comments,
                                     :order => "'created' desc",
                                     :per_page => 10)
  end

  # show_observation.rhtml -> add_comment.rhtml
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

  # left panel -> list_observations.rhtml
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
  def show_observation
    store_location
    @observation = Observation.find(params[:id])
    session[:observation] = @observation
  end

  # list_observations.rhtml -> new_observation.rhtml
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
      @observation.destroy
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

  helper_method :check_permission
  def check_permission(user_id)
    !@session['user'].nil? && ((user_id == session['user'].id) || (session['user'].id == 0))
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
