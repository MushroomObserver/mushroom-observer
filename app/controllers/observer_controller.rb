# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'find'
require 'ftools'

class Search
  attr_accessor :pattern
end

class ObserverController < ApplicationController
  before_filter :login_required, :except => (CSS + [:ask_webmaster_question,
                                                    :color_themes,
                                                    :images_by_title,
                                                    :index,
                                                    :intro,
                                                    :list_comments,
                                                    :list_images,
                                                    :list_observations,
                                                    :list_rss_logs,
                                                    :list_species_lists,
                                                    :news,
                                                    :next_image,
                                                    :next_observation,
                                                    :observations_by_name,
                                                    :observation_index,
                                                    :observation_search,
                                                    :prev_image,
                                                    :prev_observation,
                                                    :rss,
                                                    :send_webmaster_question,
                                                    :show_comment,
                                                    :show_image,
                                                    :show_observation,
                                                    :show_original,
                                                    :show_rss_log,
                                                    :show_species_list,
                                                    :species_lists_by_title])
  # Default page
  def index
    list_rss_logs
    render :action => 'list_rss_logs'
  end

  def login
    list_rss_logs
    render :action => 'list_rss_logs'
  end

  # left-hand panel -> list_comments.rhtml
  def list_comments
    @session['observation_ids'] = nil
    @session['image_ids'] = nil
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
      @observation = @comment.observation
      # @comment.observation = @observation
      @comment.user = user
      if @comment.save
        @observation.log(sprintf('Comment, %s, added by %s', @comment.summary, user.login), true)
        flash[:notice] = 'Comment was successfully added.'
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
        if @comment.save
          @comment.observation.log(sprintf('Comment, %s, updated by %s',
                                           @comment.summary, @session['user'].login), true)
          flash[:notice] = 'Comment was successfully updated.'
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
      @comment.observation.log(sprintf('Comment, %s, destroyed by %s',
                                       @comment.summary, @session['user'].login), false)
      @comment.destroy
      redirect_to :action => 'show_observation', :id => id
    else
      render :action => 'show_comment'
    end
  end

  # left-hand panel -> list_observations.rhtml
  def list_observations
    store_location
    @layout = calc_layout_params
    @observation_pages, @observations = paginate(:observations,
                                                 :order => "'when' desc",
                                                 :per_page => @layout["count"])
  end

  # left-hand panel -> observations_by_name.rhtml
  def observations_by_name
    store_location
    @layout = calc_layout_params
    @observation_pages, @observations = paginate(:observations,
                                                 :order => "'what' asc",
                                                 :per_page => @layout["count"])
    render :action => 'list_observations'
  end

  # left-hand panel -> observation_search.rhtml
  def observation_search
    store_location
    @layout = calc_layout_params
    search_data = params[:search]
    if search_data
      @session["pattern"] = search_data["pattern"]
    end
    pattern = @session["pattern"]
    if pattern.nil?
      pattern = ''
    end
    @search = Search.new
    @search.pattern = pattern
    conditions = sprintf("what like '%s%%'", pattern.gsub(/[*']/,"%"))
    @observation_pages, @observations = paginate(:observations,
                                                 :order => "'what' asc",
                                                 :conditions => conditions,
                                                 :per_page => @layout["count"])
    render :action => 'list_observations'
  end

  # observation_index.rhtml
  def observation_index
    store_location
    # Used to be:
    # @observations = Observation.find(:all, :order => "'what' asc, 'when' desc")
    # Now use straight SQL to avoid extracting user info for each observation
    @data = Observation.connection.select_all("select o.id, o.what, o.when, u.name, u.login" +
                                              " from observations o, users u" +
                                              " where o.user_id = u.id" +
                                              " order by 'what' asc, 'when' desc")
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
  		@session['image_ids'] = nil
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
        @observation.log('Observation created by ' + @session['user'].login, true)
        flash[:notice] = 'Observation was successfully created.'
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

        @observation.log('Observation updated by ' + @session['user'].login,
                         params[:log_change][:checked] == '1')

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
      for l in @observation.species_lists
        l.log(sprintf('Observation, %s, destroyed by %s', @observation.unique_name, @session['user'].login))
      end
      @observation.orphan_log('Observation destroyed by ' + @session['user'].login)
      @observation.comments.each {|c| c.destroy }
      @observation.destroy
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
		@session['image_ids'] = nil
    store_location
    @layout = calc_layout_params
    @image_pages, @images = paginate(:images,
                                     :order => "'when' desc",
                                     :per_page => @layout["count"])
  end

  # images_by_title.rhtml
  def images_by_title
    @session['observation_ids'] = nil
		@session['image_ids'] = nil
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
        for o in @image.observations
          o.log(sprintf('Image, %s, updated by %s', @image.unique_name, @session['user'].login), true)
        end
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
      image_name = @image.unique_name
      for observation in Observation.find(:all, :conditions => sprintf("thumb_image_id = '%s'", @image.id))
        observation.log(sprintf('Image, %s, destroyed by %s', image_name, @session['user'].login), false)
        observation.thumb_image_id = nil
        observation.save
      end
      @image.destroy
      redirect_to :action => 'list_images'
    else
      render :action => 'show_image'
    end
  end

  # show_observation.rhtml -> reuse_image.rhtml
  def reuse_image
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      @image = Image.new
      @image.copyright_holder = @session['user'].legal_name
      @layout = calc_layout_params
      @image_pages, @images = paginate(:images,
                                       :order => "'when' desc",
                                       :per_page => @layout["count"])
    else
      render :action => 'show_observation'
    end
  end

  # deprecated
  def manage_images
    @observation = Observation.find(params[:id])
    logger.error("manage_images has been deprecated")
    flash[:notice] = 'manage_images has been deprecated'
    redirect_to(:action => 'show_observation', :id => @observation)
  end

  # show_observation.rhtml -> add_image.rhtml
  def add_image
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      @image = Image.new
      @image.copyright_holder = @session['user'].legal_name
    else
      render :action => 'show_observation'
    end
  end

  # test method for debugging image loading
  def do_load_test
    now = Time.now
    image_field = params[:image][:image]
    logger.warn(sprintf("  *** start %s: %s", now, image_field))
    content_type = image_field.content_type.chomp
    @img = image_field.read
    logger.warn(sprintf("  *** end %s: %s", now, Time.now))
    render :action => 'load_test'
  end

  # show_observation.rhtml -> remove_images.rhtml
  def remove_images
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      @image = Image.new
      @image.copyright_holder = @session['user'].legal_name
    else
      render :action => 'show_observation'
    end
  end
  
  def upload_image
    @observation = Observation.find(params[:observation][:id])
    if check_user_id(@observation.user_id)
      # Upload image
      @image = Image.new(params[:image])
      @image.created = Time.now
      @image.modified = @image.created
      @image.user = @session['user']
      if @image.save
        if @image.save_image
          @observation.log(sprintf('Image, %s, created by %s', @image.unique_name, @session['user'].login), true)
          @observation.add_image(@image)
          @observation.save
        else
          logger.error("Unable to upload image")
          flash[:notice] = 'Invalid image'
        end
      end
      redirect_to(:action => 'show_observation', :id => @observation)
    else
      render :action => 'show_observation'
    end
  end

  # remove_images.rhtml -> delete_images -> show_observation.rhtml
  def delete_images
    @observation = Observation.find(params[:observation][:id])
    if check_user_id(@observation.user_id)
      # Delete images
      images = params[:selected]
      if images
        images.each do |image_id, do_it|
          if do_it == 'yes'
            image = @observation.remove_image_by_id(image_id)
            if !image.nil?
              @observation.log(sprintf('Image, %s, removed by %s', image.unique_name, @session['user'].login), false)
            end
          end
        end
      end
      redirect_to(:action => 'show_observation', :id => @observation)
    else
      render :action => 'show_observation'
    end
  end

  def add_image_to_obs
    @observation = Observation.find(params[:obs_id])
    if check_user_id(@observation.user_id)
      image = @observation.add_image_by_id(params[:id])
      if !image.nil?
        @observation.log(sprintf('Image, %s, reused by %s', image.unique_name, @session['user'].login), true)
      end
      redirect_to(:action => 'show_observation', :id => @observation)
    end
  end
  
  # reuse_image.rhtml -> reuse_image_by_id -> show_observation.rhtml
  def reuse_image_by_id
    @observation = Observation.find(params[:observation][:id])
    if check_user_id(@observation.user_id)
      image = @observation.add_image_by_id(params[:observation][:idstr].to_i)
      if !image.nil?
        @observation.log(sprintf('Image, %s, reused by %s', image.unique_name, @session['user'].login), true)
      end
      redirect_to(:action => 'show_observation', :id => @observation)
    end
  end

  # deprecated along with manage_images
  def save_image
    @observation = @session[:observation]
    logger.error("save_image has been deprecated")
    flash[:notice] = 'save_image has been deprecated'
    redirect_to(:action => 'show_observation', :id => @observation)
  end


  # left-hand panel -> new_species_list.rhtml
  def new_species_list
    user = @session['user']
    if verify_user(user)
  		@session['observation_ids'] = nil
  		@session['image_ids'] = nil
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
        @species_list.log('Species list created by ' + @session['user'].login)
        flash[:notice] = 'Species list was successfully created.'
        notes = params[:member][:notes]
        @species_list.process_file_data(@session['user'], notes)
        redirect_to :action => 'list_species_lists'
        species = args["species"]
        args.delete("species")
        args.delete("title")
        args.delete("file")
        args["notes"] = notes
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
		@session['image_ids'] = nil
    store_location
    @species_list_pages, @species_lists = paginate(:species_lists,
                                                   :order => "'when' desc",
                                                   :per_page => 10)
  end

  # list_species_lists.rhtml -> destroy -> list_species_lists.rhtml
  def destroy_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id)
      @species_list.orphan_log('Species list destroyed by ' + @session['user'].login)
      @species_list.destroy
      redirect_to :action => 'list_species_lists'
    else
      render :action => 'show_species_list'
    end
  end

  # species_lists_by_title.rhtml
  def species_lists_by_title
		@session['observation_ids'] = nil
		@session['image_ids'] = nil
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
        if @species_list.save
          @species_list.log('Species list updated by ' + @session['user'].login)
          flash[:notice] = 'Species List was successfully updated.'
          notes = params[:member][:notes]
          @species_list.process_file_data(@session['user'], notes)
          new_species = args["species"]
          args.delete("species")
          args.delete("title")
          args.delete("file")
          args["created"] = now
          args["user"] = @session['user']
          args["notes"] = notes
          for s in new_species
            @species_list.construct_observation(s.strip(), args)
          end
        end
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
    user = @session['user']
    if verify_user(user)
      @observation = @session[:observation]
    end
  end

  # users_by_name.rhtml
  # Restricted to the admin user
  def users_by_name
    if check_permission(0)
      @users = User.find(:all, :order => "'last_login' desc")
    else
      redirect_to :action => 'list_observations'
    end
  end
  
  def ask_webmaster_question
    @user = @session['user']
  end
  
  def send_webmaster_question
    sender = @params['user']['email']
    if sender.nil? or sender.strip == ''
      flash[:notice] = "You must provide a return address."
      redirect_to :action => 'ask_webmaster_question'
    else
      AccountMailer.deliver_webmaster_question(@params['user']['email'], @params['question']['content'])
      flash[:notice] = "Delivered question or comment."
      redirect_back_or_default :action => "list_rss_logs"
    end
  end

  # email_features.rhtml
  # Restricted to the admin user
  def email_features
    if check_permission(0)
      @users = User.find(:all, :conditions => "feature_email=1")
    else
      redirect_to :action => 'list_observations'
    end
  end
  
  def test_feature_email
    users = User.find(:all, :conditions => "feature_email=1")
    user = users[1]
    email = AccountMailer.create_email_features(user, @params['feature_email']['content'])
    render(:text => "<pre>" + email.encoded + "</pre>")
  end
  
  def send_feature_email
    users = User.find(:all, :conditions => "feature_email=1")
    for user in users
      AccountMailer.deliver_email_features(user, @params['feature_email']['content'])
    end
    flash[:notice] = "Delivered feature mail."
    redirect_to :action => 'users_by_name'
  end

  def ask_question
    @observation = Observation.find(params['id'])
    if !@observation.user.question_email
      flash[:notice] = "Permission denied"
      redirect_to :action => 'show_observation', :id => @observation
    end
  end
  
  def test_question
    sender = @session['user']
    observation = Observation.find(params['id'])
    question = @params['question']['content']
    email = AccountMailer.create_question(sender, observation, question)
    render(:text => "<pre>" + email.encoded + "</pre>")
  end
  
  def send_question
    sender = @session['user']
    observation = Observation.find(params['id'])
    question = @params['question']['content']
    AccountMailer.deliver_question(sender, observation, question)
    flash[:notice] = "Delivered question."
    redirect_to :action => 'show_observation', :id => observation
  end

  def commercial_inquiry
    @image = Image.find(params['id'])
    if !@image.user.commercial_email
      flash[:notice] = "Permission denied"
      redirect_to :action => 'show_image', :id => @image
    end
  end
  
  def test_commercial_inquiry
    sender = @session['user']
    image = Image.find(params['id'])
    commercial_inquiry = @params['commercial_inquiry']['content']
    email = AccountMailer.create_commercial_inquiry(sender, image, commercial_inquiry)
    render(:text => "<pre>" + email.encoded + "</pre>")
  end
  
  def send_commercial_inquiry
    sender = @session['user']
    image = Image.find(params['id'])
    commercial_inquiry = @params['commercial_inquiry']['content']
    AccountMailer.deliver_commercial_inquiry(sender, image, commercial_inquiry)
    flash[:notice] = "Delivered commercial inquiry."
    redirect_to :action => 'show_image', :id => image
  end

  def rss
    @headers["Content-Type"] = "application/xml" 
    @logs = RssLog.find(:all, :order => "'modified' desc",
                        :conditions => "datediff(now(), modified) <= 31")
    render_without_layout
  end
  
  # left-hand panel -> list_rss_logs.rhtml
  def list_rss_logs
    store_location
    @layout = calc_layout_params
    @rss_log_pages, @rss_logs = paginate(:rss_log,
                                      :order => "'modified' desc",
                                      :per_page => @layout["count"])
  end
  
  def show_rss_log
    store_location
    @rss_log = RssLog.find(params['id'])
  end

  # Calculation of the image_ids should be lazier.  Currently it calculates all the image_ids
  # for all the observation_ids.  Instead, image_ids should just be the ids for the 'current'
  # observation, and if you run out of those, then walk through observation_ids until you
  # find more images.
  def prev_image
    @image = Image.find(params[:id])
    image_ids = @session['image_ids']
    if image_ids.nil?
      image_ids = calc_image_ids(@session['observation_ids'])
      @session['image_ids'] = image_ids
    end
    index = 0
    id = 0
    if not image_ids.nil?
      current_index = image_ids.index(params[:id])
      if current_index and image_ids.length > 0
        index = current_index - 1
        if index < 0
          index = image_ids.length - 1
        end
      end
      id = image_ids[index]
    end
    redirect_to :action => 'show_image', :id => id
  end

  def next_image
    @image = Image.find(params[:id])
    image_ids = @session['image_ids']
    if image_ids.nil?
      image_ids = calc_image_ids(@session['observation_ids'])
      @session['image_ids'] = image_ids
    end
    index = 0
    id = 0
    if not image_ids.nil?
      current_index = image_ids.index(params[:id])
      if current_index and image_ids.length > 0
        index = current_index + 1
        if index >= image_ids.length
          index = 0
        end
      end
      id = image_ids[index]
    end
    redirect_to :action => 'show_image', :id => id
  end

  def resize_images
    if check_permission(0)
      for image in Image.find(:all)
        image.calc_size()
        image.resize_image(160, 160, image.thumbnail)
      end
    else
      flash[:notice] = "You must be an admin to access resize_images"
    end
    redirect_to :action => 'list_images'
  end
  
  helper_method :check_permission
  def check_permission(user_id)
    user = @session['user']
    !user.nil? && user.verified && ((user_id == @session['user'].id) || (@session['user'].id == 0))
  end
  
  helper_method :calc_color
  def calc_color(row, col, alt_rows, alt_cols)
    color = 0
		if alt_rows
			color = row % 2
		end
		if alt_cols
			if (col % 2) == 1
				color = 1 - color
			end
		end
		color
	end

  helper_method :calc_image_ids
  def calc_image_ids(obs)
    result = nil
    if obs
      result = []
      for ob_id in obs:
        img_ids = Observation.connection.select_all("select image_id from images_observations" +
                                          " where observation_id=" + ob_id.to_s)
        for h in img_ids
          result.push(h['image_id'])
        end
      end
    end
    result
  end
  
  helper_method :calc_layout_params
  def calc_layout_params
    result = {}
    result["rows"] = 5
    result["columns"] = 3
    result["alternate_rows"] = true
    result["alternate_columns"] = true
    result["vertical_layout"] = true
    user = @session['user']
    if user
      result["rows"] = user.rows if user.rows
      result["columns"] = user.columns if user.columns
      result["alternate_rows"] = user.alternate_rows
      result["alternate_columns"] = user.alternate_columns
      result["vertical_layout"] = user.vertical_layout
    end
    result["count"] = result["rows"] * result["columns"]
    result
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
