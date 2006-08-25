# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'find'
require 'ftools'

class ObserverController < ApplicationController
  before_filter :login_required, :except => (CSS + [:color_themes, :images_by_title, :index,
                                                    :intro, :list_comments, :list_images, :list_observations,
                                                    :list_species_lists, :news, :next_observation,
                                                    :observations_by_name, :prev_observation, :rss,
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
    @session['observation_ids'] = nil
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
    if verify_user(@session['user'])
      @comment = Comment.new
      @observation = @session[:observation]
    end
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
    user = @session['user']
    if verify_user(user)
      @comment = Comment.new(params[:comment])
      @comment.created = Time.now
      @observation = @session[:observation]
      @comment.observation = @observation
      @comment.user = user
      if @comment.save
        flash[:notice] = 'Comment was successfully added.'
        rss = RssEvent.new({:title => 'Comment created: ' + @comment.summary,
                            :who => user.login,
                            :date => Time.now,
                            :url => sprintf('/observer/show_comment/%d', @comment.id)})
        if rss
          rss.save
        end
        redirect_to(:action => 'show_observation', :id => @observation)
      else
        flash[:notice] = sprintf('Unable to save comment: %s', @comment.summary)
        render :action => 'add_comment'
      end
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
        rss = RssEvent.new({:title => "Comment updated: " + @comment.summary,
                            :who => @session['user'].login,
                            :date => Time.now,
                            :url => sprintf('/observer/show_comment/%d', @comment.id)})
        if rss
          rss.save
        end
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
      rss = RssEvent.new({:title => "Comment destroyed: " + @comment.summary,
                          :who => @session['user'].login,
                          :date => Time.now,
                          :url => sprintf('/observer/show_observation/%d', id)})
      if rss
        rss.save
      end
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
    @session[:observation] = @observation
  end

  # left-hand panel -> new_observation.rhtml
  def new_observation
    if verify_user(@session['user'])
  		@session['observation_ids'] = nil
      @observation = Observation.new
      @observation.what = 'Unknown'
    end
  end

  # new_observation.rhtml -> list_observations.rhtml
  def create_observation
    user = @session['user']
    if verify_user(user)
      @observation = Observation.new(params[:observation])
      now = Time.now
      @observation.created = now
      @observation.modified = now
      @observation.user = user
      if @observation.save
        flash[:notice] = 'Observation was successfully created.'
        rss = RssEvent.new({:title => "Observation created: " + @observation.unique_name,
                            :who => user.login,
                            :date => now,
                            :url => sprintf('/observer/show_observation/%d', @observation.id)})
        if rss
          rss.save
        end
        redirect_to :action => 'show_observation', :id => @observation
      else
        render :action => 'new_observation'
      end
    end
  end
  
  # list_observation.rhtml, show_observation.rhtml -> edit_observation.rhtml
  # Setup session to have the right observation.
  def edit_observation
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      @session[:observation] = @observation
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
        @observation.modified = Time.now
        # @observation.touch
        @observation.save

        flash[:notice] = 'Observation was successfully updated.'
        rss = RssEvent.new({:title => "Observation updated: " + @observation.unique_name,
                            :who => @session['user'].login,
                            :date => Time.now,
                            :url => sprintf('/observer/show_observation/%d', @observation.id)})
        if rss
          rss.save
        end
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
      rss = RssEvent.new({:title => "Observation destroyed: " + @observation.unique_name,
                          :who => @session['user'].login,
                          :date => Time.now,
                          :url => '/observer/list_observations'})
      if rss
        rss.save
      end
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

  def prev_observation
    @observation = Observation.find(params[:id])
    obs = @session['observation_ids']
    index = obs.index(params[:id].to_i)
    if index.nil? or obs.nil? or obs.length == 0
      index = 0
    else
      index = index - 1
      if index < 0
        index = obs.length - 1
      end
    end
    id = obs[index]
    redirect_to :action => 'show_observation', :id => id
  end

  def next_observation
    @observation = Observation.find(params[:id])
    obs = @session['observation_ids']
    index = obs.index(params[:id].to_i)
    if index.nil? or obs.nil? or obs.length == 0
      index = 0
    else
      index = index + 1
      if index >= obs.length
        index = 0
      end
    end
    id = obs[index]
    redirect_to :action => 'show_observation', :id => id
  end

      
  ## Image support

  # Various -> list_images.rhtml
  def list_images
    @session['observation_ids'] = nil
    store_location
    @image_pages, @images = paginate(:images,
                                     :order => "'when' desc",
                                     :per_page => 10)
  end

  # images_by_title.rhtml
  def images_by_title
    @session['observation_ids'] = nil
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
        rss = RssEvent.new({:title => "Image updated: " + @image.unique_name,
                            :who => @session['user'].login,
                            :date => @image.modified,
                            :url => sprintf('/observer/show_image/%d', @image.id)})
        if rss
          rss.save
        end
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
        rss = RssEvent.new({:title => "Image destroyed: " + @image.unique_name,
                            :who => @session['user'].login,
                            :date => Time.now,
                            :url => sprintf('/observer/show_observation/%d', observation.id)})
        if rss
          rss.save
        end
      end
      @image.destroy
      redirect_to :action => 'list_images'
    else
      render :action => 'show_image'
    end
  end

  # show_observation.rhtml -> manage_images.rhtml
  def manage_images
    @observation = @session[:observation]
    if check_user_id(@observation.user_id)
      @img = Image.new
    else
      render :action => 'show_observation'
    end
  end
  
  # manage_images.rhtml -> save_image -> show_observation.rhtml
  def save_image
    @observation = @session[:observation]
    if check_user_id(@observation.user_id)
      # Upload image
      @img = Image.new(params[:image])
      @img.created = Time.now
      @img.modified = @img.created
      @img.user = @session['user']
      if @img.save
        if @img.save_image
          rss = RssEvent.new({:title => "Image created: " + @img.unique_name,
                              :who => @session['user'].login,
                              :date => @img.created,
                              :url => sprintf('/observer/show_image/%d', @img.id)})
          if rss
            rss.save
          end
          @observation.add_image(@img)
          @observation.save
        else
          logger.error("Unable to save image")
          flash[:notice] = 'Invalid image'
        end
      end
    
      # Or reuse image by id
      @observation.add_image_by_id(params[:observation][:idstr].to_i)
      redirect_to(:action => 'show_observation', :id => @observation)
    
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


  # left-hand panel -> new_species_list.rhtml
  def new_species_list
    user = @session['user']
    if verify_user(user)
  		@session['observation_ids'] = nil
      @species_list = SpeciesList.new
    end
  end

  def create_species_list
    user = @session['user']
    if verify_user(user)
      args = params[:species_list]
      now = Time.now
      args["created"] = now
      args["modified"] = now
      args["user"] = user
      @species_list = SpeciesList.new(args)

      if @species_list.save
        flash[:notice] = 'Species list was successfully created.'
        rss = RssEvent.new({:title => "Species list created: " + @species_list.unique_name,
                            :who => user.login,
                            :date => now,
                            :url => sprintf('/observer/show_species_list/%d', @species_list.id)})
        if rss
          rss.save
        end
        redirect_to :action => 'list_species_lists'
        species = args["species"]
        args.delete("species")
        args.delete("title")
        for s in species
          @species_list.construct_observation(s.strip(), args)
        end
      else
        render :action => 'new_species_list'
      end
    end
  end

  # list_species_list.rhtml & notes links -> show_species_list.rhtml
  # Use session to store the current species list since this parallels
  # the usage for show_observation.
  def show_species_list
    store_location
    @species_list = SpeciesList.find(params[:id])
    @session[:species_list] = @species_list
  end

  # Needs both a species_list and an observation.
  def remove_observation_from_species_list
    species_list = SpeciesList.find(params[:species_list])
    if check_user_id(species_list.user_id)
      observation = Observation.find(params[:observation])
      species_list.modified = Time.now
      species_list.observations.delete(observation)
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
		@session['observation_ids'] = nil
    store_location
    @species_list_pages, @species_lists = paginate(:species_lists,
                                                   :order => "'when' desc",
                                                   :per_page => 10)
  end

  # list_species_lists.rhtml -> destroy -> list_species_lists.rhtml
  def destroy_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id)
      rss = RssEvent.new({:title => "Species list destroyed: " + @species_list.unique_name,
                          :who => @session['user'].login,
                          :date => Time.now,
                          :url => 'list_species_lists'})
      if rss
        rss.save
      end
      @species_list.destroy
      redirect_to :action => 'list_species_lists'
    else
      render :action => 'show_species_list'
    end
  end

  # species_lists_by_title.rhtml
  def species_lists_by_title
		@session['observation_ids'] = nil
    store_location
    @species_lists = SpeciesList.find(:all, :order => "'what' asc, 'when' desc")
  end

  # list_species_list.rhtml, show_species_list.rhtml -> edit_species_list.rhtml
  # Setup session to have the right species_list.
  def edit_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id)
      @session[:species_list] = @species_list
    else 
      render :action => 'show_species_list'
    end
  end

  # edit_species_list.rhtml -> show_species_list.rhtml
  # Updates modified and saves changes
  def update_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id) # Even though edit makes this check, avoid bad guys going directly
      args = params[:species_list]
      if @species_list.update_attributes(args)
        now = Time.now
        @species_list.modified = now
        redirect_to :action => 'show_species_list', :id => @species_list
        if @species_list.save
          flash[:notice] = 'Species List was successfully updated.'
          rss = RssEvent.new({:title => "Species list updated: " + @species_list.unique_name,
                              :who => @session['user'].login,
                              :date => now,
                              :url => sprintf('/observer/show_species_list/%d', @species_list.id)})
          if rss
            rss.save
          end
          new_species = args["species"]
          args.delete("species")
          args.delete("title")
          args["created"] = now
          args["user"] = @session['user']
          for s in new_species
            @species_list.construct_observation(s.strip(), args)
          end
        end
      else
        render :action => 'edit_species_list'
      end
    else
      render :action => 'show_species_list'
    end
  end

  # show_observation.rhtml -> manage_species_lists.rhtml
  def manage_species_lists
    user = @session['user']
    if verify_user(user)
      @observation = @session[:observation]
    end
  end

  # users_by_name.rhtml
  def users_by_name
    user = @session['user']
    if check_permission(0)
      @users = User.find(:all, :order => "'last_login' desc")
    else
      redirect_to :action => 'list_observations'
    end
  end

  def rss
    @headers["Content-Type"] = "application/xml" 
    @events = RssEvent.find(:all, :order => "'date' desc")
    render_without_layout
  end
  
  helper_method :check_permission
  def check_permission(user_id)
    user = @session['user']
    !user.nil? && user.verified && ((user_id == @session['user'].id) || (@session['user'].id == 0))
  end

  protected

  def check_user_id(user_id)
    result = check_permission(user_id)
    unless result
      flash[:notice] = 'Permission denied.'
    end
    result
  end

  def verify_user(user)
    result = false
    if @session['user'].verified.nil?
      redirect_to :controller => 'account', :action=> 'reverify', :id => @session['user'].id
    else
      result = true
    end
    result
  end
  # Look in obs_extras.rb for code for uploading directory trees of images.
end
