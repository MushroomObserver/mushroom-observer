# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'find'
require 'ftools'

class Search
  attr_accessor :pattern
end

class ObserverController < ApplicationController
  before_filter :login_required, :except => (CSS + [:all_names,
                                                    :ask_webmaster_question,
                                                    :color_themes,
                                                    :do_load_test,
                                                    :how_to_use,
                                                    :images_by_title,
                                                    :index,
                                                    :intro,
                                                    :list_comments,
                                                    :list_images,
                                                    :list_observations,
                                                    :list_rss_logs,
                                                    :list_species_lists,
                                                    :name_index,
                                                    :news,
                                                    :next_image,
                                                    :next_observation,
                                                    :observation_index,
                                                    :observations_by_name,
                                                    :pattern_search,
                                                    :prev_image,
                                                    :prev_observation,
                                                    :rss,
                                                    :send_webmaster_question,
                                                    :show_comment,
                                                    :show_comments_for_user,
                                                    :show_image,
                                                    :show_name,
                                                    :show_observation,
                                                    :show_original,
                                                    :show_past_name,
                                                    :show_rss_log,
                                                    :show_site_stats,
                                                    :show_species_list,
                                                    :show_user,
                                                    :show_user_observations,
                                                    :species_lists_by_title,
                                                    :throw_error,
                                                    :users_by_contribution])

  def auto_complete_for_observation_where
    part = params[:observation][:where].downcase.gsub(/[*']/,"%")
    @items = Observation.find(:all, {
      :conditions => "LOWER(observations.where) LIKE '#{part}%'",
      :order => "observations.where ASC",
      :limit => 10,
    })
    render :inline => "<%= content_tag('ul', @items.map { |entry| content_tag('li', content_tag('nobr', h(entry['where']))) }.uniq) %>"
  end

  def auto_complete_for_observation_what
    # Added ?: after an exception was thrown in which observation was nil
    part = params[:observation] ? params[:observation][:what].downcase.gsub(/[*']/,"%") : ''
    @items = []
    if (part.index(' ').nil?)
      @items = Name.find(:all, {
        :conditions => "LOWER(text_name) LIKE '#{part}%' AND text_name NOT LIKE '% %'",
        :order => "text_name ASC",
        :limit => 100
      })
    end
    if (@items.length < 100)
      @items += Name.find(:all, {
        :conditions => "LOWER(text_name) LIKE '#{part}%'",
        :order => "text_name ASC",
        :limit => 100 - @items.length
      })
      @items.sort! {|a,b| a['text_name'] <=> b['text_name']}
    end
    render :inline => "<%= content_tag('ul', @items.map { |entry| content_tag('li', content_tag('nobr', h(entry['text_name']))) }.uniq) %>"
  end

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
    store_location
    session['observation_ids'] = nil
    session['observation'] = nil
    session['image_ids'] = nil
    @comment_pages, @comments = paginate(:comments,
                                     :order => "'created' desc",
                                     :per_page => 10)
  end

  def add_comment
    if verify_user()
      @comment = Comment.new
      @observation = Observation.find(params[:id])
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
    user = session['user']
    if verify_user()
      @comment = Comment.new(params[:comment])
      @comment.created = Time.now
      @observation = @comment.observation
      # @comment.observation = @observation
      @comment.user = user
      if @comment.save
        @observation.log("Comment, #{@comment.summary}, added by #{user.login}", true)
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
                                           @comment.summary, session['user'].login), true)
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
                                       @comment.summary, session['user'].login), false)
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
    session['checklist_source'] = nil # Meaning all species
    session['observation_ids'] = self.query_ids("select id, `when` from observations order by `when` desc")
    session['observation'] = nil
    session['image_ids'] = nil
    @observation_pages, @observations = paginate(:observations,
                                                 :order => "`when` desc",
                                                 :per_page => @layout["count"])
  end

  # left-hand panel -> observations_by_name.rhtml
  def observations_by_name
    store_location
    @layout = calc_layout_params
    session['checklist_source'] = nil # Meaning all species
    session['observation_ids'] = self.query_ids("select o.id, n.search_name from observations o, names n where n.id = o.name_id order by text_name asc, `when` desc")
    session['observation'] = nil
    session['image_ids'] = nil
    @observation_pages, @observations = paginate(:observations, :include => "name",
                                                 :order => "names.search_name asc, `when` desc",
                                                 :per_page => @layout["count"])
    render :action => 'list_observations'
  end

  # pattern_search.rhtml
  def pattern_search
    store_location
    @layout = calc_layout_params
    search_data = params[:search]
    if search_data
      session["pattern"] = search_data["pattern"]
    end
    pattern = session["pattern"]
    if pattern.nil?
      pattern = ''
    end
    # Setup the search string for the next page
    @search = Search.new
    @search.pattern = pattern
    if params[:commit]
      session["search_type"] = params[:commit]
    end
    case session["search_type"]
    when 'Images'
      image_search(pattern)
    when 'Names'
      name_search(pattern)
    else
      observation_search(pattern)
    end
  end

  def field_search(fields, sql_pattern)
    (fields.map{|n| "#{n} like '#{sql_pattern}'"}).join(' or ')
  end

  def image_search(pattern)
    sql_pattern = "%#{pattern.gsub(/[*']/,"%")}%"
    conditions = field_search(["names.search_name", "images.notes", "images.copyright_holder"], sql_pattern)
    query = "select images.*, names.search_name from images, images_observations, observations, names
      where images.id = images_observations.image_id and images_observations.observation_id = observations.id
      and observations.name_id = names.id and (#{conditions}) order by names.search_name, `when` desc"
    session['checklist_source'] = 0 # Meaning use observation_ids
    session['observation_ids'] = []
    session['observation'] = nil
    session['image_ids'] = self.query_ids(query)
    @image_pages, @images = paginate_by_sql(Image, query, @layout["count"])
    render :action => 'list_images'
  end

  def observation_search(pattern)
    sql_pattern = "%#{pattern.gsub(/[*']/,"%")}%"
    conditions = field_search(["names.search_name", "observations.where", "observations.notes"], sql_pattern)
    query = "select observations.id, names.search_name from observations, names
             where observations.name_id = names.id and (#{conditions}) order by names.search_name asc, `when` desc"
    session['checklist_source'] = 0 # Meaning use observation_ids
    session['observation_ids'] = self.query_ids(query)
    session['observation'] = nil
    session['image_ids'] = nil
    @observation_pages, @observations = paginate(:observations, :include => "name",
                                                 :order => "names.search_name asc, `when` desc",
                                                 :conditions => conditions,
                                                 :per_page => @layout["count"])
    render :action => 'list_observations'
  end

  def name_search(pattern)
    sql_pattern = "%#{pattern.gsub(/[*']/,"%")}%"
    conditions = field_search(["names.search_name", "names.notes", "names.citation"], sql_pattern)
    session['checklist_source'] = nil # Meaning all species
    @name_data = Name.connection.select_all("select distinct names.id, " +
      "names.display_name from names where #{conditions} " +
      "order by names.text_name asc, author asc")
    len = @name_data.length
    if len == 1
      redirect_to(:controller => 'observer', :action => 'show_name', :id => @name_data[0]['id'])
    else
      if len == 0
        flash[:notice] = "No names matching '%s' found" % pattern
      end
      render :action => 'name_index'
    end
  end

  # list_observations.rhtml -> show_observation.rhtml
  # Setup session to have the right observation.
  def show_observation
    store_location # Is this doing anything useful since there is no user check for this page?
    @observation = Observation.find(params[:id])
    session['observation'] = params[:id].to_i
    session['image_ids'] = nil
  end

  # left-hand panel -> create_observation.rhtml
  def create_observation
    if verify_user()
      session[:observation_ids] = nil
      session[:observation] = nil
      session[:image_ids] = nil
      args = session[:args]
      session[:args] = nil
      if args
        @observation = Observation.new(args)
        @what = args[:what] # Given name
        name_ids = session[:name_ids]
        if name_ids # multiple matches or deprecated name
          @names = name_ids.map {|n| Name.find(n)}
        end
        session[:name_ids] = nil
        valid_name_ids = session[:valid_name_ids]
        if valid_name_ids
          @valid_names = valid_name_ids.map {|n| Name.find(n)}
        end
        session[:valid_name_ids] = nil
      else
        @observation = Observation.new
      end
    end
  end

  def construct_observation
    user = session['user']
    if verify_user()
      action = "create_observation"
      if params[:observation]
        @observation = Observation.new(params[:observation])
        now = Time.now
        @observation.created = now
        @observation.modified = now
        @observation.user = user
        if params[:chosen_name] && params[:chosen_name][:name_id]
          names = [Name.find(params[:chosen_name][:name_id])]
        else
          names = Name.find_names(params[:observation][:what])
          logger.warn("construct_observation: #{names.length}")
        end
        if names.length == 0
          names = [create_needed_names(params[:approved_name], params[:observation][:what], user)]
        end
        target_name = names.first
        if target_name and names.length == 1
          if target_name.deprecated && (params[:approved_name] != params[:observation][:what])
            synonyms = target_name.approved_synonyms
            session[:valid_name_ids] = synonyms.map {|n| n.id}
          else
            @observation.name = target_name
            if @observation.save
              @observation.log('Observation created by ' + session['user'].login, true)
              flash[:notice] = 'Observation was successfully created.'
              action = "show_observation"
            else
              if params[:observation][:where] == ''
                flash[:notice] = 'Location not given!'
              else
                flash[:notice] = 'Unable to create a new Observation'
              end
            end
          end
        end
      end
      if action == "create_observation"
        args = params[:observation]
        if args
          args[:user_id] = user.id
          session[:args] = args
        end
        if target_name
          session[:name_ids] = names.map {|n| n.id}
        else
          session[:name_ids] = []
        end
      end
      redirect_to :action => action, :id => @observation
    end
  end

  # list_observation.rhtml, show_observation.rhtml -> edit_observation.rhtml
  # Setup session to have the right observation.
  def edit_observation
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      session['observation'] = params[:id].to_i
      if session[:args]
        @what = session[:args][:what]
        @observation.attributes = session[:args]
        session[:args] = nil
      end
      name_ids = session[:name_ids]
      if name_ids
        @names = name_ids.map {|n| Name.find(n)}
      end
      session[:name_ids] = nil
      valid_name_ids = session[:valid_name_ids]
      if valid_name_ids
        @valid_names = valid_name_ids.map {|n| Name.find(n)}
      end
      session[:valid_name_ids] = nil
    else
      render :action => 'show_observation'
    end
  end

  # edit_observation.rhtml -> show_observation.rhtml
  # Updates modified and saves changes
  def update_observation
    @observation = Observation.find(params[:id])
    action = 'show_observation'
    if check_user_id(@observation.user_id) # Even though edit makes this check, avoid bad guys going directly
      action = 'edit_observation'
      user = session['user']
      if params[:chosen_name] && params[:chosen_name][:name_id]
        names = [Name.find(params[:chosen_name][:name_id])]
      else
        names = Name.find_names(params[:observation][:what])
      end
      if names.length == 0
        names = [create_needed_names(params[:approved_name], params[:observation][:what], user)]
      end
      target_name = names.first
      if target_name and names.length == 1
        if target_name.deprecated && (params[:approved_name] != params[:observation][:what])
          synonyms = target_name.approved_synonyms
          session[:valid_name_ids] = synonyms.map {|n| n.id}
        elsif @observation.update_attributes(params[:observation])
          @observation.name = target_name
          @observation.modified = Time.now
          @observation.save
          @observation.log('Observation updated by ' + session['user'].login,
                           params[:log_change][:checked] == '1')
          flash[:notice] = 'Observation was successfully updated.'
          action = 'show_observation'
        end
      end
      if action == "edit_observation"
        session[:args] = params[:observation]
        if target_name
          session[:name_ids] = names.map {|n| n.id}
        else
          session[:name_ids] = []
        end
      end
      redirect_to :action => action, :id => @observation
    else
      render :action => action
    end
  end

  # list_observations.rhtml -> destroy -> list_observations.rhtml
  def destroy_observation
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      for l in @observation.species_lists
        l.log(sprintf('Observation, %s, destroyed by %s', @observation.unique_text_name, @observation.id, session['user'].login))
      end
      @observation.orphan_log('Observation destroyed by ' + session['user'].login)
      @observation.comments.each {|c| c.destroy }
      @observation.destroy
      redirect_to :action => 'list_observations'
    else
      render :action => 'show_observation'
    end
  end

  def prev_observation
    @observation = Observation.find(params[:id])
    obs = session['observation_ids']
    if obs
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
      redirect_to(:action => 'show_observation', :id => id)
    else
      redirect_to(:action => 'list_rss_logs')
    end
  end

  def next_observation
    @observation = Observation.find(params[:id])
    obs = session['observation_ids']
    if obs
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
      redirect_to(:action => 'show_observation', :id => id)
    else
      redirect_to(:action => 'list_rss_logs')
    end
  end


  ## Image support

  # Various -> list_images.rhtml
  def list_images
    session['checklist_source'] = nil # Meaning all species
    session['observation_ids'] = []
    session['observation'] = nil
    session['image_ids'] = self.query_ids("select id, `when` from images order by `when` desc")

    store_location
    @layout = calc_layout_params
    @image_pages, @images = paginate(:images,
                                     :order => "`when` desc",
                                     :per_page => @layout["count"])
  end

  # images_by_title.rhtml
  def images_by_title
    session['checklist_source'] = nil # Meaning all species
    session['observation_ids'] = nil
    session['observation'] = nil
    session['image_ids'] = nil
    store_location
    @images = Image.find(:all, :order => "'title' asc, 'when' desc")
  end

  # list_images -> show_image.rhtml
  # show_original.rhtml -> show_image.rhtml
  # Thumbnails should hook up to this
  def show_image
    store_location
    @invalid = true # Until the about= thing gets resolved
    @image = Image.find(params[:id])
  end

  # show_image.rhtml -> show_original.rhtml
  def show_original
    store_location
    @invalid = true # Until the about= thing gets resolved
    @image = Image.find(params[:id])
  end

  # list_images.rhtml, show_image.rhtml -> edit_image.rhtml
  def edit_image
    @image = Image.find(params[:id])
    @licenses = License.current_names_and_ids(@image.license)
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
          o.log(sprintf('Image, %s, updated by %s', @image.unique_text_name, session['user'].login), true)
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
      image_name = @image.unique_text_name
      for observation in Observation.find(:all, :conditions => sprintf("thumb_image_id = '%s'", @image.id))
        observation.log(sprintf('Image, %s, destroyed by %s', image_name, session['user'].login), false)
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
      # @image = Image.new
      # @image.copyright_holder = session['user'].legal_name
      @layout = calc_layout_params
      @image_pages, @images = paginate(:images,
                                       :order => "'when' desc",
                                       :per_page => @layout["count"])
    else
      render :action => 'show_observation'
    end
  end

  def license_updater
    if verify_user()
      id = session['user'].id.to_i # Make sure it's an integer
      query = "select count(*) as license_count, copyright_holder, license_id from images where user_id = #{id} group by copyright_holder, license_id"
      @data = Image.connection.select_all(query)
      for datum in @data
        license = License.find(datum['license_id'])
        datum['license_name'] = license.display_name
        datum['select_id'] = "updates_#{datum['license_id']}_#{datum['copyright_holder']}".gsub!(' ', '_')
        datum['select_name'] = "updates[#{datum['license_id']}][#{datum['copyright_holder']}]"
        datum['licenses'] = License.current_names_and_ids(license)
        datum['selected'] = license.id
      end
    end
  end

  def update_licenses
    for current_id, value in params[:updates]
      current_id = current_id.to_i
      for copyright_holder, new_id in value
        new_id = new_id.to_i
        if current_id != new_id
          for image in Image.find_all_by_copyright_holder_and_license_id(copyright_holder, current_id)
            image.license_id = new_id
            image.save
          end
        end
      end
    end
    redirect_to :action => 'license_updater'
  end

  # show_observation.rhtml -> add_image.rhtml
  def add_image
    begin # Should figure out how to propagate this around
      @observation = Observation.find(params[:id])
      if check_user_id(@observation.user_id)
        @image = Image.new
        @image.license = session['user'].license
        @image.copyright_holder = session['user'].legal_name

        # Set the default date to the date of the observation
        # Don't know how to correctly test this.
        @image.when = @observation.when

        @licenses = License.current_names_and_ids(@image.license)
      else
        render :action => 'show_observation'
      end
    rescue ActiveRecord::RecordNotFound
      flash[:notice] = 'Invalid observation'
      redirect_to(:action => 'list_rss_logs')
    end
  end

  # show_observation.rhtml -> remove_images.rhtml
  def remove_images
    @observation = Observation.find(params[:id])
    if check_user_id(@observation.user_id)
      # @image = Image.new
      # @image.copyright_holder = session['user'].legal_name
    else
      render :action => 'show_observation'
    end
  end

  def process_image(args, upload)
    if upload and upload != ""
      args[:image] = upload
      @image = Image.new(args)
      @image.created = Time.now
      @image.modified = @image.created
      @image.user = session['user']
      if @image.save
        if @image.save_image
          @observation.log(sprintf('Image, %s, created by %s', @image.unique_text_name, session['user'].login), true)
          @observation.add_image(@image)
          @observation.save
        else
          logger.error("Unable to upload image")
          flash[:notice] = 'Invalid image'
        end
      end
    end
  end

  def upload_image
    if params[:observation]
      id = params[:observation][:id]
      @observation = Observation.find(id)
      if check_user_id(@observation.user_id)
        # Upload image
        args = params[:image]
        process_image(args, params[:upload][:image1])
        process_image(args, params[:upload][:image2])
        process_image(args, params[:upload][:image3])
        process_image(args, params[:upload][:image4])
        redirect_to(:action => 'show_observation', :id => id)
      else
        render :action => 'show_observation', :id => id
      end
    else
      render :action => 'list_rss_logs'
    end
  end

  def test_process_image(user, upload, count, size)
    if upload and upload != ""
      args = {
        :user => user,
        :image => upload
      }
      @image = Image.new(args)
      @image.id = user.id
      @image.img_dir = TEST_IMG_DIR
      @image.save_image
      count += 1
      size += File.new(@image.original_image).stat.size
    end
    [count, size]
  end

  def test_upload_image
    if verify_user()
      @log_entry = AddImageTestLog.find(params[:log_id])
      @log_entry.upload_start = Time.now
      @log_entry.save # Record that upload started
      user= session['user']
      @log_entry.upload_data_start = Time.now # Just in case save takes a long time
      count, size = test_process_image(user, params[:upload][:image1], 0, 0)
      count, size = test_process_image(user, params[:upload][:image2], count, size)
      count, size = test_process_image(user, params[:upload][:image3], count, size)
      count, size = test_process_image(user, params[:upload][:image4], count, size)
      @log_entry.upload_end = Time.now
      @log_entry.image_count = count
      @log_entry.image_bytes = size
      @log_entry.save
      redirect_to(:action => 'test_add_image_report')
    end
  end

  def test_add_image
    if verify_user()
      @log_entry = AddImageTestLog.new
      @log_entry.user = session['user']
      @log_entry.save
      @upload = {}
    end
  end

  def test_add_image_report
    if verify_user()
      @log_entries = AddImageTestLog.find(:all, :order => 'created_at desc')
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
              @observation.log(sprintf('Image, %s, removed by %s', image.unique_text_name, session['user'].login), false)
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
        @observation.log("Image, %s, reused by %s" % [image.unique_text_name, session['user'].login], true)
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
        @observation.log(sprintf('Image, %s, reused by %s', image.unique_text_name, session['user'].login), true)
      end
    end
    redirect_to(:action => 'show_observation', :id => @observation)
  end

  def calc_checklist(id)
    source = session['checklist_source']
    list = []
    query = nil
    if source == id
      source = session['prev_checklist_source'] || source
    end
    if source == 0 # Use observation_ids
      ob_ids = session['observation_ids']
      if ob_ids
        checklist = {}
        for o in ob_ids
          obs = Observation.find(o)
          if obs
            name = obs.name
            # Generate a list of unique name strings and id strings.
            # It's important to use strings to be able to match the
            # information that comes back from the check_boxes.
            checklist[[name.observation_name, name.id.to_s]] = true
          end
        end
        session['checklist'] = checklist.keys.sort
      end
    elsif source.to_s == 'all_observations'
      query = "select distinct names.observation_name, names.id, names.search_name from names, observations
               where names.id = observations.name_id order by names.search_name"
    elsif source.to_s == 'all_names'
      query = "select distinct observation_name, id, search_name from names order by search_name"
    elsif not source.nil? # Used to list everything, but that's too slow
      query = "select distinct names.observation_name, names.id, names.search_name from names, observations, observations_species_lists
               where observations_species_lists.species_list_id = %s
               and observations_species_lists.observation_id = observations.id
               and names.id = observations.name_id order by names.search_name" % source.to_i
    end
    if query
      data = Observation.connection.select_all(query)
      for d in data
        list.push([d['observation_name'], d['id']])
      end
    end
    session['checklist'] = list
  end

  # left-hand panel -> create_species_list.rhtml
  def create_species_list
    if verify_user()
      read_spl_session
      calc_checklist(nil)
    end
  end

  # name_index/create_species_list -> bulk_name_edit
  def bulk_name_edit
    if verify_user()
      @list_members = session['list_members']
      session['list_members'] = nil
      @new_names = session['new_names']
      session['new_names'] = nil
    end
  end

  # list_species_list.rhtml & notes links -> show_species_list.rhtml
  # Use session to store the current species list since this parallels
  # the usage for show_observation.
  def show_species_list
    store_location
    read_spl_session
    id = params[:id]
    @species_list = SpeciesList.find(id)
    session[:species_list] = @species_list
    if session['checklist_source'] != id
      session['prev_checklist_source'] = session['checklist_source']
      session['checklist_source'] = id
    end
  end

  # Needs both a species_list and an observation.
  def remove_observation_from_species_list
    species_list = SpeciesList.find(params[:species_list])
    if check_user_id(species_list.user_id)
      observation = Observation.find(params[:observation])
      species_list.modified = Time.now
      species_list.observations.delete(observation)
      redirect_to(:action => 'manage_species_lists', :id => observation)
    else
      redirect_to(:action => 'show_species_list', :id => species_list)
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
    session['observation_ids'] = nil
    session['observation'] = nil
    session['image_ids'] = nil
    store_location
    @species_list_pages, @species_lists = paginate(:species_lists,
                                                   :order => "'when' desc, 'id' desc",
                                                   :per_page => 10)
  end

  # list_species_lists.rhtml -> destroy -> list_species_lists.rhtml
  def destroy_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id)
      @species_list.orphan_log('Species list destroyed by ' + session['user'].login)
      @species_list.destroy
      redirect_to :action => 'list_species_lists'
    else
      render :action => 'show_species_list'
    end
  end

  # species_lists_by_title.rhtml
  def species_lists_by_title
    session['observation_ids'] = nil
    session['observation'] = nil
    session['image_ids'] = nil
    store_location
    @species_lists = SpeciesList.find(:all, :order => "'title' asc, 'when' desc")
  end

  # list_species_list.rhtml, show_species_list.rhtml -> edit_species_list.rhtml
  # Setup session to have the right species_list.
  def edit_species_list
    spl = SpeciesList.find(params[:id])
    if check_user_id(spl.user_id)
      read_spl_session # Clears @species_list
      @species_list = spl
      for obs in spl.observations
        name = obs.name
        if name.deprecated
          @deprecated_names = [] if @deprecated_names.nil?
          unless @deprecated_names.member?(name.search_name) or @deprecated_names.member?(name.text_name)
            @deprecated_names.push(name.search_name)
          end
        end
      end
      calc_checklist(params[:id])
    else
      @species_list = spl
      render :action => 'show_species_list'
    end
  end

  def upload_species_list
    species_list = SpeciesList.find(params[:id])
    @species_list = species_list
    if !check_user_id(species_list.user_id)
      render :action => 'show_species_list'
    end
  end

  def read_species_list
    species_list = SpeciesList.find(params[:id])
    if species_list
      file_data = params[:species_list][:file]
      species_list.file = file_data
      sorter = NameSorter.new
      species_list.process_file_data(sorter)
      species_list_action('edit_species_list', params[:id], {}, '', {}, sorter)
    end
  end

  def construct_approved_name(name_parse, approved_names, user, deprecate)
    # Don't do anything if the given names are not approved
    if approved_names.member?(name_parse.search_name)
      names = Name.names_from_string(name_parse.search_name)
      if names.last.nil?
        flash[:notice] = "Unable to create the name #{name_parse.name}\n"
      else
        names.last.rank = name_parse.rank if name_parse.rank
        save_names(names, user, deprecate)
      end
    end
    if name_parse.has_synonym && approved_names.member?(name_parse.synonym_search_name)
      synonym_names = []
      synonym_names = Name.names_from_string(name_parse.synonym_search_name)
      if synonym_names.last.nil?
        flash[:notice] = "Unable to create the synonym #{name_parse.synonym}\n"
      else
        synonym_name = synonym_names.last
        synonym_name.rank = name_parse.synonym_rank if name_parse.synonym_rank
        synonym_name.change_deprecated(true)
        unless PastName.check_for_past_name(synonym_name, user, "Deprecated by #{user.login}")
          synonym_name.user = user
          synonym_name.save
        end
        save_names(synonym_names[0..-2], user, nil) # Don't change higher taxa
      end
    end
  end

  def save_names(names, user, deprecate)
    msg = nil
    unless deprecate.nil?
      if deprecate
        msg = "Deprecated by #{user.login}"
      else
        msg = "Approved by #{user.login}"
      end
    end
    for n in names
      n.change_deprecated(deprecate) unless deprecate.nil? or n.id?
      unless PastName.check_for_past_name(n, user, msg)
        unless n.id # Only save if it's brand new
          n.user = user
          n.save
        end
      end
    end
  end

  def construct_approved_names(name_list, approved_names, user, deprecate=false)
    if approved_names
      if approved_names.class == String
        approved_names = approved_names.split("/")
      end
      for ns in name_list
        if ns.strip != ''
          name_parse = NameParse.new(ns)
          construct_approved_name(name_parse, approved_names, user, deprecate)
        end
      end
    end
  end

  # Verify the user and derive the species list.  If id is provided then
  # load the species list from the database, otherwise use the args.
  def get_user_and_species_list(id, args)
    user = nil
    species_list = nil
    now = Time.now
    if id
      species_list = SpeciesList.find(id)
      user_id = species_list.user_id
      if check_user_id(user_id)
        user = species_list.user
        species_list.modified = now
        if not species_list.update_attributes(params[:species_list]) # Does save
          species_list = nil
        end
      end
    else
      user = session['user']
      if session['user'].verified
        if args
          args["created"] = now
          args["modified"] = now
          args["user"] = user
          species_list = SpeciesList.new(args)
        end
      else
        user = nil
      end
    end
    [user, species_list]
  end

  def species_list_action(action, id, args, notes, names, sorter)
    # Store all the state in the session since we can't put it in the database yet
    # and it's too awkward to pass through the URL effectively
    session['species_list'] = SpeciesList.new(args) if args
    session['list_members'] = sorter.all_line_strs.join("\r\n")
    session['checklist_names'] = names
    session['new_names'] = sorter.new_name_strs.uniq.sort
    session['multiple_names'] = sorter.multiple_line_strs.uniq.sort
    session['deprecated_names'] = sorter.deprecated_name_strs.uniq.sort
    session['member_notes'] = notes
    redirect_to :action => action, :id => id
  end

  def setup_sorter(params, species_list, list)
    sorter = NameSorter.new

    # Seems like valid selections should take precedence over multiple names,
    # but I haven't constructed a lot of examples.  If it makes more sense for multiples
    # to take precedence over valid names, then swap the next two lines.
    # If they need to be more carefully considered, then the lists may need to get
    # merged in the display.
    sorter.add_chosen_names(params[:chosen_names]) # hash
    sorter.add_chosen_names(params[:chosen_approved_names]) # hash

    sorter.add_approved_deprecated_names(params[:approved_deprecated_names])
    sorter.check_for_deprecated_checklist(params[:checklist_data])
    if species_list
      sorter.check_for_deprecated_names(species_list.observations.map {|o| o.name})
    end
    sorter.sort_names(list)
    sorter
  end

  def construct_observations(species_list, params, type_str, user, sorter)
    species_list.log("Species list %s by %s" % [type_str, user.login])
    flash[:notice] = "Species List was successfully %s." % type_str
    sp_args = { :created => species_list.modified, :user => user, :notes => params[:member][:notes],
                :where => species_list.where }
    sp_when = species_list.when # Can't use params since when is split up
    species_list.update_names(params[:chosen_approved_names])
    for name, timestamp in sorter.single_names
      sp_args[:when] = timestamp || sp_when
      species_list.construct_observation(name, sp_args)
    end
    sp_args[:when] = sp_when
    if params[:checklist_data]
      for key, value in params[:checklist_data]
        if value == "checked"
          name = find_chosen_name(key.to_i, params[:chosen_approved_names])
          species_list.construct_observation(name, sp_args)
        end
      end
    end
  end

  def process_species_list(id, params, type_str, action)
    args = params[:species_list]
    user, species_list = get_user_and_species_list(id, args)
    if user && species_list
      list = params[:list][:members]
      construct_approved_names(list, params[:approved_names], user)
      sorter = setup_sorter(params, species_list, list)
      if sorter.has_new_synonyms
        flash[:notice] = "Synonyms can only be created from the Bulk Name Edit page."
        sorter.reset_new_names
      elsif sorter.only_single_names
        if sorter.has_unapproved_deprecated_names
          flash[:notice] = "Found deprecated names"
        elsif species_list.save
          construct_observations(species_list, params, type_str, user, sorter)
          action = 'show_species_list'
          id = species_list.id
          args = nil
        else
          flash[:notice] = "Save failed.  Did you provide all required fields?"
        end
      elsif sorter.new_name_strs != []
        flash[:notice] = "Unrecognized names including %s given" % sorter.new_name_strs[0]
      else
        flash[:notice] = "Ambiguous names including %s given" % sorter.multiple_line_strs[0]
      end # sorter.only_single_names
      notes = ''
      notes = params[:member][:notes] if params[:member]
      species_list_action(action, id, args, notes, params[:checklist_data], sorter)
    else
      redirect_to :action => 'list_species_lists'
      if session['user']
        flash[:notice] = "You can only edit species lists you created"
      else
        flash[:notice] = "You must login to create or modify species lists"
      end
    end
  end

  def find_chosen_name(id, alternatives)
    name = Name.find(id)
    if alternatives
      alt_id = alternatives[name.search_name]
      if alt_id
        name = Name.find(alt_id.to_i)
      end
    end
    name
  end

  def update_species_list
    process_species_list(params[:id], params, 'updated', 'edit_species_list')
  end

  def construct_species_list
    process_species_list(nil, params, 'created', 'create_species_list')
  end

  def update_bulk_names
    id = nil
    action = 'bulk_name_edit'
    if verify_user()
      list = params[:list][:members]
      construct_approved_names(list, params[:approved_names], session['user'])
      sorter = setup_sorter(params, nil, list)
      if sorter.only_single_names
        sorter.create_new_synonyms()
        flash[:notice] = "All names are now in the database."
        action = 'list_rss_logs'
      elsif sorter.new_name_strs != []
        flash[:notice] = "Unrecognized names including %s given" % sorter.new_name_strs[0]
      else
        flash[:notice] = "Ambiguous names including %s given" % sorter.multiple_line_strs[0]
      end # sorter.only_single_names
      session['list_members'] = sorter.all_line_strs.join("\r\n")
      session['new_names'] = sorter.new_name_strs.uniq.sort
      redirect_to :action => action, :id => id
    end
  end

  # show_observation.rhtml -> manage_species_lists.rhtml
  def manage_species_lists
    if verify_user()
      @observation = Observation.find(params[:id])
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

  # users_by_contribution.rhtml
  def users_by_contribution
    @user_ranking = SiteData.new.get_user_ranking
  end

  # show_user.rhtml
  def show_user
    store_location
    id = params[:id]
    if id
      @user_data = SiteData.new.get_user_data(id)
      @observations = Observation.find(:all, :conditions => ["user_id = ? and thumb_image_id is not null", id],
        :order => "id desc", :limit => 6)
    else
      redirect_to :action => 'users_by_contribution'
    end
  end

  # show_site_stats.rhtml
  def show_site_stats
    store_location
    id = params[:id]
    @site_data = SiteData.new.get_site_data
    @observations = Observation.find(:all, :conditions => ["thumb_image_id is not null"],
      :order => "id desc", :limit => 6)
  end

  def show_user_observations
    store_location
    user = User.find(params[:id])
    @layout = calc_layout_params
    @title = "Observations by %s" % user.legal_name
    conditions = "observations.user_id = %s" % user.id
    order = "observations.modified desc, `when` desc"
    query = "select observations.id, names.search_name from observations, names
             where observations.name_id = names.id and %s order by %s" % [conditions, order]
    session['checklist_source'] = 0 # Meaning use observation_ids
    session['observation_ids'] = self.query_ids(query)
    session['observation'] = nil
    session['image_ids'] = nil
    @observation_pages, @observations = paginate(:observations, :include => "name",
                                                 :order => order,
                                                 :conditions => conditions,
                                                 :per_page => @layout["count"])
    render :action => 'list_observations'
  end

  def show_comments_for_user
    store_location
    user = User.find(params[:id])
    @title = "Comments for %s" % user.legal_name
    session['observation_ids'] = nil
    session['observation'] = nil
    session['image_ids'] = nil
    @comment_pages, @comments = paginate(:comments, :include => "observation",
                                         :order => "comments.created desc",
                                         :conditions => "observations.user_id = %s" % user.id,
                                         :per_page => 10)
    render :action => 'list_comments'
  end

  def ask_webmaster_question
    @sender = session['sender']
    session['sender'] = nil
    @content = session['content']
    session['content'] = nil
    @user = session['user']
  end

  def send_webmaster_question
    sender = nil
    content = ''
    if params['user']
      sender = params['user']['email']
    end
    if params['question']
      content = params['question']['content']
    end
    if sender.nil? or sender.strip == '' or sender.index('@').nil?
      flash[:notice] = "You must provide a valid return address."
      session['content'] = content
      redirect_to :action => 'ask_webmaster_question'
    elsif /http:/ =~ content or /<[\/a-zA-Z]+>/ =~ content
      flash[:notice] = "To cut down on robot spam, questions from unregistered users cannot contain 'http:' or HTML markup."
      session['sender'] = sender
      session['content'] = content
      redirect_to :action => 'ask_webmaster_question'
    else
      AccountMailer.deliver_webmaster_question(sender, content)
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

  def send_feature_email
    if check_permission(0)
      users = User.find(:all, :conditions => "feature_email=1")
      for user in users
        AccountMailer.deliver_email_features(user, params['feature_email']['content'])
      end
      flash[:notice] = "Delivered feature mail."
      redirect_to :action => 'users_by_name'
    else
      flash[:notice] = "Only the admin can send feature mail."
      redirect_to :action => "list_rss_logs"
    end
  end

  def ask_question
    @observation = Observation.find(params['id'])
    if !@observation.user.question_email
      flash[:notice] = "Permission denied"
      redirect_to :action => 'show_observation', :id => @observation
    end
  end

  def send_question
    sender = session['user']
    observation = Observation.find(params['id'])
    question = params['question']['content']
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

  def send_commercial_inquiry
    sender = session['user']
    image = Image.find(params['id'])
    commercial_inquiry = params['commercial_inquiry']['content']
    AccountMailer.deliver_commercial_inquiry(sender, image, commercial_inquiry)
    flash[:notice] = "Delivered commercial inquiry."
    redirect_to :action => 'show_image', :id => image
  end

  def rss
    headers["Content-Type"] = "application/xml"
    @logs = RssLog.find(:all, :order => "'modified' desc",
                        :conditions => "datediff(now(), modified) <= 31",
                        :limit => 100)
    render_without_layout
  end

  # left-hand panel -> list_rss_logs.rhtml
  def list_rss_logs
    store_location
    @layout = calc_layout_params
    session['checklist_source'] = nil # Meaning all species
    query = "select observation_id as id, modified from rss_logs where observation_id is not null and " +
            "modified is not null order by 'modified' desc"
    session['observation_ids'] = self.query_ids(query)
    session['observation'] = nil
    session['image_ids'] = nil
    @rss_log_pages, @rss_logs = paginate(:rss_log,
                                         :order => "'modified' desc",
                                         :per_page => @layout["count"])
  end

  def show_rss_log
    store_location
    @rss_log = RssLog.find(params['id'])
  end

  def next_image
    current_image_id = params[:id].to_i
    (image_ids, current_observation) = current_image_state
    if image_ids # nil value means it wasn't set and the session data doesn't have anything to help
      obs_ids = session['observation_ids']
      if image_ids == [] # current image list is empty, try for the next
        image_ids, current_observation = next_image_list(current_observation, obs_ids)
      end
      if image_ids != [] # empty list means there isn't a next_image_list with any content
        index = image_ids.index(current_image_id)
        if index.nil? # Not in the list so start at the first element
          current_image_id = image_ids[0]
        else
          index = index + 1
          if index >= image_ids.length # Run off the end of the current list
            image_ids, current_observation = next_image_list(current_observation, obs_ids)
            if image_ids != [] # Just in case
              current_image_id = image_ids[0]
            end
          else
            current_image_id = image_ids[index]
          end
        end
      end
    end
    session['image_ids'] = image_ids
    session['observation'] = current_observation
    redirect_to :action => 'show_image', :id => current_image_id
  end

  def prev_image
    current_image_id = params[:id].to_i
    (image_ids, current_observation) = current_image_state
    if image_ids # nil value means it wasn't set and the session data doesn't have anything to help
      obs_ids = session['observation_ids']
      if image_ids == [] # current image list is empty, try for the next
        image_ids, current_observation = prev_image_list(current_observation, obs_ids)
      end
      if image_ids != [] # empty list means there isn't a next_image_list with any content
        index = image_ids.index(current_image_id)
        if index.nil? # Not in the list so start with the last element
          current_image_id = image_ids[-1]
        else
          index = index - 1
          if index < 0 # Run off the front of the current list
            image_ids, current_observation = prev_image_list(current_observation, obs_ids)
            if image_ids != [] # Just in case
              current_image_id = image_ids[-1]
            end
          else
            current_image_id = image_ids[index]
          end
        end
      end
    end
    session['image_ids'] = image_ids
    session['observation'] = current_observation
    redirect_to :action => 'show_image', :id => current_image_id
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

  def show_past_name
    store_location
    @past_name = PastName.find(params[:id])
    @other_versions = PastName.find(:all, :conditions => "name_id = %s" % @past_name.name_id, :order => "version desc")
  end

  # show_name.rhtml
  def show_name
    # Rough testing showed implementation without synonyms takes .23-.39 secs.
    # elapsed_time = Benchmark.realtime do
      store_location
      read_syn_session
      @name = Name.find(params[:id])
      @past_name = PastName.find(:all, :conditions => "name_id = %s and version = %s" % [@name.id, @name.version - 1]).first
      query = "select o.id, o.when, o.modified, o.when, o.thumb_image_id, o.where," +
              " u.name, u.login, n.observation_name from observations o, users u, names n" +
              " where n.id = %s and o.user_id = u.id and n.id = o.name_id order by o.when desc"
      @data = Observation.connection.select_all(query % params[:id])
      observation_ids = []
      @data.each {|d| observation_ids.push(d["id"].to_i)}

      @synonym_data = []
      synonym = @name.synonym
      if synonym
        for n in synonym.names
          if n != @name
            data = Observation.connection.select_all(query % n.id)
            data.each {|d| observation_ids.push(d["id"].to_i)}
            @synonym_data += data
          end
        end
      end
      session['checklist_source'] = 0 # Meaning use observation_ids
      session['observation_ids'] = observation_ids
      session['image_ids'] = nil
    # end
    # logger.warn("show_name took %s\n" % elapsed_time)
  end

  # show_name.rhtml -> edit_name.rhtml
  def edit_name
    if verify_user()
      @name = Name.find(params[:id])
      user_id = session['user'].id
      @can_make_changes = true
      if user_id != 0
        for obs in @name.observations
          if obs.user_id != user_id
            @can_make_changes = false
            break
          end
        end
      end
    end
  end

  # Finds the intended name and if another name matching name exists,
  # then ensure it is mergable.
  def find_target_names(id_str, text_name, author)
    id = id_str.to_i
    page_name = Name.find(id)
    other_name = nil
    matches = []
    if author != ''
      matches = Name.find(:all, :conditions => "text_name = '%s' and author = '%s'" % [text_name, author])
    else
      matches = Name.find(:all, :conditions => "text_name = '%s'" % text_name)
    end
    for m in matches
      if m.id != id
        other_name = m # Just take the first one
        break
      end
    end
    if other_name
      result = [other_name, page_name]
      if page_name.mergable?
        if other_name.mergable? # Need some other criterion
          if other_name.deprecated and !page_name.deprecated # Prefer valid names
            result = [page_name, other_name]
          elsif (other_name.deprecated == page_name.deprecated) and (other_name.version < page_name.version)
            # Prefer longer histories
            result = [page_name, other_name]
          end
        end
      elsif other_name.mergable?
        result = [page_name, other_name]
      else
        raise "The name, %s, is already in use and both %s and %s have notes" % [text_name, page_name.search_name, other_name.search_name]
      end
    else
      result = [page_name, other_name]
    end
    result
  end

  # edit_name.rhtml -> show_name.rhtml
  # Updates modified and saves changes
  def update_name
    user = session['user']
    if verify_user()
      text_name = (params[:name][:text_name] || '').strip
      author = (params[:name][:author] || '').strip
      begin
        (name, old_name) = find_target_names(params[:id], text_name, author)
        if text_name == ''
          text_name = name.text_name
        end
        # Don't allow author to be cleared by using any author you can find...
        if author == ''
          author = name.author || ''
          if author == '' && old_name
            author = old_name.author || ''
          end
        end
        old_search_name = name.search_name
        count = 0
        current_time = Time.now
        name.modified = current_time
        count += 1
        alt_ids = name.change_text_name(text_name, author, params[:name][:rank])
        name.citation = params[:name][:citation]
        name.notes = params[:name][:notes]
        unless PastName.check_for_past_name(name, user, "Name updated by #{user.login}")
          unless name.id
            raise "update_name called on a name that doesn't exist"
          end
        end
        if old_name # merge happened
          for o in old_name.observations
            o.name = name
            o.modified = current_time
            o.save
          end
          old_name.log("#{old_search_name} merged with #{name.search_name}")
          old_name.destroy
        end
      rescue RuntimeError => err
        flash[:notice] = err.to_s
        redirect_to :action => 'edit_name', :id => name
      else
        redirect_to :action => 'show_name', :id => name
      end
    end
  end

  # List all the names
  def name_index
    store_location
    session['list_members'] = nil
    session['new_names'] = nil
    session['checklist_source'] = :all_names
    @name_data = Name.connection.select_all("select id, display_name from names" +
                                            " order by text_name asc, author asc")
  end

  # Just list the names that have observations
  def observation_index
    store_location
    session['list_members'] = nil
    session['new_names'] = nil
    session['checklist_source'] = :all_observations
    @title = "Observation Index"
    @name_data = Name.connection.select_all("select distinct names.id, names.display_name from names, observations" +
                                            " where observations.name_id = names.id" +
                                            " order by names.text_name asc, author asc")
    render :action => 'name_index'
  end

  def all_names
    name_index # Maintaining backwards compatibility
    render :action => 'name_index'
  end

  # show_name.rhtml -> change_synonyms.rhtml
  def change_synonyms
    read_syn_session
    if verify_user()
      @name = Name.find(params[:id])
    end
  end

  # change_synonyms.rhtml -> transfer_synonyms -> show_name.rhtml
  def transfer_synonyms
    id = params[:id]
    name = Name.find(id)
    user = session['user']
    action = 'show_name'
    if verify_user()
      list = params[:synonym][:members]
      deprecate = (params[:deprecate][:all] == "checked")
      construct_approved_names(list, params[:approved_names], user, deprecate)
      sorter = NameSorter.new
      sorter.sort_names(list)
      sorter.append_approved_synonyms(params[:approved_synonyms])
      if sorter.only_single_names and sorter.only_approved_synonyms
        timestamp = Time.now
        synonym = name.synonym
        if synonym.nil?
          synonym = Synonym.new
          synonym.created = timestamp
          name.synonym = synonym
          name.modified = timestamp # Change timestamp, but not modifier
          name.save # Not creating a PastName since they don't track synonyms
        end
        proposed_synonyms = params[:proposed_synonyms] || {}
        for n in sorter.all_names
          if proposed_synonyms[n.id.to_s] != '0'
            synonym.transfer(n)
          end
        end
        for name_id in sorter.proposed_synonym_ids
          n = Name.find(name_id)
          if proposed_synonyms[name_id.to_s] != '0'
            synonym.transfer(n)
          end
        end
        check_for_new_synonym(name, synonym.names, params[:existing_synonyms] || {})
        synonym.modified = timestamp
        synonym.save
        if deprecate
          for n in sorter.all_names
            action = deprecate_synonym(n, user)
          end
        end
      else
        action = 'change_synonyms'
        dump_sorter(sorter)
      end
      synonym_action(action, id, sorter, params[:deprecate][:all])
    end
  end

  def deprecate_synonym(name, user)
    action = 'show_name'
    unless name.deprecated
      begin
        count = 0
        name.change_deprecated(true)
        PastName.check_for_past_name(name, user, "Name deprecated by #{user.login}")
      rescue RuntimeError => err
        flash[:notice] = err.to_s
        action = 'change_synonyms'
      end
    end
    action
  end

  def deprecate_name
    read_syn_session
    if verify_user()
      @name = Name.find(params[:id])
      name_ids = session[:name_ids]
      if name_ids # multiple matches or deprecated name
        @names = name_ids.map {|n| Name.find(n)}
      end
      session[:name_ids] = nil
      @what = params[:proposed_name] || ''
      @comment = params[:comment] || ''
    end
  end

  def do_deprecation
    user = session['user']
    if verify_user()
      current_name = Name.find(params[:id])
      proposed_name_str = (params[:proposed][:name] || '').strip
      comment = (params[:comment][:comment] || '').strip
      action = 'deprecate_name'
      if proposed_name_str != ''
        if params[:chosen_name] && params[:chosen_name][:name_id]
          names = [Name.find(params[:chosen_name][:name_id])]
        else
          names = Name.find_names(proposed_name_str)
        end
        if names.length == 0
          logger.warn("do_deprecation: create_needed_names(#{params[:approved_name]}, #{proposed_name_str}, user)")
          names = [create_needed_names(params[:approved_name], proposed_name_str, user)]
          logger.warn("do_deprecation: #{names.length}")
        end
        target_name = names.first
        if target_name
          if names.length == 1
            target_name = names.first
            current_name.merge_synonyms(target_name)
            target_name.change_deprecated(false)
            current_time = Time.now
            PastName.check_for_past_name(target_name, user, "Preferred over #{current_name.search_name} by #{user.login}")
            current_name.change_deprecated(true)
            PastName.check_for_past_name(current_name, user, "Deprecated in favor of #{target_name.search_name} by #{user.login}")
            comment_join = comment == "" ? "." : ":\n"
            current_name.prepend_notes("Deprecated in favor of" +
              " #{target_name.search_name} by #{user.login} on " +
              Time.now.to_formatted_s(:db) + comment_join + comment)
            action = 'show_name'
          else # must have multiple matches
            # setup name_ids, proposed/name
            session[:name_ids] = names.map {|n| n.id}
          end
        end
        redirect_to :action => action, :id => current_name, :proposed_name => proposed_name_str, :comment => comment
      end
    end
  end

  def approve_name
    if verify_user()
      @name = Name.find(params[:id])
      @approved_names = @name.approved_synonyms
    end
  end

  def do_approval
    user = session['user']
    if verify_user()
      current_name = Name.find(params[:id])
      if params[:deprecate][:others] == '1'
        for n in current_name.approved_synonyms
          n.change_deprecated(true)
          PastName.check_for_past_name(n, user, "Deprecated in favor of #{current_name.search_name} by #{user.login}")
        end
      end
      # current_name.version = current_name.version + 1
      current_name.change_deprecated(false)
      PastName.check_for_past_name(current_name, user, "Approved by #{user.login}")
      comment = (params[:comment][:comment] || '').strip
      comment_join = comment == "" ? "." : ":\n"
      current_name.prepend_notes("Approved by #{user.login} on " +
        Time.now.to_formatted_s(:db) + comment_join + comment)
      redirect_to :action => 'show_name', :id => current_name
    end
  end

  def throw_error
    if request.env["HTTP_USER_AGENT"].index("BlackBerry")
      raise "This is a BlackBerry!"
    else
      raise "#{request.env["HTTP_USER_AGENT"]}"
    end
  end

  def cleanup_versions
    if check_permission(1)
      id = params[:id]
      name = Name.find(id)
      past_names = PastName.find(:all, :conditions => ["name_id = ?", id], :order => "version desc")
      v = past_names.length
      name.version = v
      name.user_id = 1
      name.save
      v -= 1
      for pn in past_names
        pn.version = v
        pn.save
        v -= 1
      end
    end
    redirect_to :action => 'show_name', :id => id
  end

  def do_maintenance
    if check_permission(0)
      @data = []
      @users = {}
      for n in Name.find(:all)
        eldest_obs = nil
        for o in n.observations
          if eldest_obs.nil? or (o.created < eldest_obs.created)
            eldest_obs = o
          end
        end
        if eldest_obs
          user = eldest_obs.user
          if n.user != user
            found_user = false
            for p in n.past_names
              if p.user == user
                found_user = true
              end
            end
            unless found_user
              if @users[user.login]
                @users[user.login] += 1
              else
                @users[user.login] = 1
              end
              @data.push({:name => n.display_name, :id => n.id, :login => user.login})
              pn = PastName.make_past_name(n)
              pn.user = user
              pn.save
              n.version += 1
              n.save
            end
          end
        end
      end
    else
      flash[:notice] = "Maintenance operations can only be done by the admin user"
      redirect_to :action => "list_rss_logs"
    end
  end

  helper_method :dump_sorter
  def dump_sorter(sorter)
    logger.warn("tranfer_synonyms: only_single_names or only_approved_synonyms is false")
    logger.warn("New names:")
    for n in sorter.new_line_strs
      logger.warn(n)
    end
    logger.warn("\nSingle names:")
    for n in sorter.single_line_strs
      logger.warn(n)
    end
    logger.warn("\nMultiple names:")
    for n in sorter.multiple_line_strs
      logger.warn(n)
    end
    if sorter.chosen_names
      logger.warn("\nChosen names:")
      for n in sorter.chosen_names
        logger.warn(n)
      end
    end
    logger.warn("\nSynonym name ids:")
    for n in sorter.proposed_synonym_ids.uniq
      logger.warn(n)
    end
  end

  helper_method :synonym_action
  def synonym_action(action, id, sorter, deprecate)
    # Store all the state in the session since we can't put it in the database yet
    # and it's too awkward to pass through the URL effectively
    session['list_members'] = sorter.all_line_strs.join("\r\n")
    session['new_names'] = sorter.new_name_strs.uniq
    psi = sorter.proposed_synonym_ids.uniq
    session['synonym_name_ids'] = psi
    session['deprecate_all'] = deprecate
    redirect_to :action => action, :id => id
  end

  helper_method :check_for_new_synonym
  # Look through the candidates for names that are not marked in checks.
  # If there are more than 1, then create a new synonym containing those taxa.
  # If there is only one then remove it from any synonym it belongs to
  def check_for_new_synonym(name, candidates, checks)
    new_synonym_members = []
    for n in candidates
      if (name != n) && (checks[n.id.to_s] == "0")
        new_synonym_members.push(n)
      end
    end
    len = new_synonym_members.length
    if len > 1
      new_synonym = Synonym.new
      new_synonym.created = Time.now
      new_synonym.save
      for n in new_synonym_members
        new_synonym.transfer(n)
      end
    elsif len == 1
      new_synonym_members[0].clear_synonym
    end
  end

  helper_method :read_syn_session
  def read_syn_session
    @list_members = session['list_members']
    session['list_members'] = nil
    @new_names = session['new_names']
    session['new_names'] = nil
    ids = session['synonym_name_ids'] || []
    @synonym_name_ids = ids
    @synonym_names = []
    for id in ids
      @synonym_names.push(Name.find(id))
    end
    session['synonym_name_ids'] = nil
    @deprecate_all = session['deprecate_all']
    if @deprecate_all.nil?
      @deprecate_all = "checked"
    end
    session['deprecate_all'] = nil
  end

  helper_method :read_spl_session
  def read_spl_session
    # Pull all the state out of the session and clean out the session
    @checklist_names = session['checklist_names'] || {}
    session['checklist_names'] = nil
    @species_list = session['species_list']
    session['species_list'] = nil
    @list_members = session['list_members']
    session['list_members'] = nil
    @new_names = session['new_names']
    session['new_names'] = nil
    @multiple_names = session['multiple_names']
    session['multiple_names'] = nil
    @deprecated_names = session['deprecated_names']
    session['deprecated_names'] = nil
    @member_notes = session['member_notes']
    session['member_notes'] = nil
  end

  # Ultimately running large queries like this and storing the info in the session
  # may become unwieldy.  Storing the query and selecting chunks will scale better.
  helper_method :query_ids
  def query_ids(query)
    result = []
    data = Observation.connection.select_all(query)
    for d in data
      id = d['id']
      if id
        result.push(id.to_i)
      end
    end
    result
  end

  # Get initial image_ids and observation_id
  helper_method :current_image_state
  def current_image_state
    obs_ids = session['observation_ids']
    observation_id = session['observation']
    if observation_id.nil? and obs_ids
      if obs_ids.length > 0
        observation_id = obs_ids[0]
      end
    end
    image_ids = session['image_ids']
    if image_ids.nil? and observation_id
      images = Observation.find(observation_id).images
      image_ids = []
      for i in images
        image_ids.push(i.id)
      end
    end
    [image_ids, observation_id]
  end

  helper_method :next_id
  def next_id(id, id_list)
    result = id
    if id_list.length > 0
      result = id_list[0]
      index = id_list.index(id)
      if index
        index = index + 1
        if index < id_list.length
          result = id_list[index]
        end
      end
    end
    result
  end

  helper_method :next_image_list
  def next_image_list(observation_id, id_list)
    image_list = []
    current_id = observation_id
    if id_list.length > 0
      index = id_list.index(observation_id)
      if index.nil?
        index = id_list.length - 1
        observation_id = id_list[index]
      end
      current_id = observation_id
      while image_list == []
        current_id = next_id(current_id, id_list)
        if current_id == observation_id
          break
        end
        images = Observation.find(current_id).images
        image_list = []
        for i in images
          image_list.push(i.id)
        end
      end
    end
    [image_list, current_id]
  end

  helper_method :prev_id
  def prev_id(id, id_list)
    result = id
    if id_list.length > 0
      result = id_list[-1]
      index = id_list.index(id)
      if index
        index = index - 1
        if index >= 0
          result = id_list[index]
        end
      end
    end
    result
  end

  helper_method :prev_image_list
  def prev_image_list(observation_id, id_list)
    image_list = []
    current_id = observation_id
    if id_list.length > 0
      index = id_list.index(observation_id)
      if index.nil?
        index = 0
        observation_id = id_list[index]
      end
      current_id = observation_id
      while image_list == []
        current_id = prev_id(current_id, id_list)
        if current_id == observation_id
          break
        end
        images = Observation.find(current_id).images
        image_list = []
        for i in images
          image_list.push(i.id)
        end
      end
    end
    [image_list, current_id]
  end

  helper_method :check_permission
  def check_permission(user_id)
    user = session['user']
    !user.nil? && user.verified && ((user_id == session['user'].id) || (session['user'].id == 0))
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
          result.push(h['image_id'].to_i)
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
    user = session['user']
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

  def create_needed_names(input_what, output_what, user)
    result = nil
    if input_what == output_what
      names = Name.names_from_string(output_what)
      if names.last.nil?
        flash[:notice] = "Unable to create the name %s" % output_what
      else
        for n in names # These names are all new
          if n.id
            PastName.check_for_past_name(n, user, "Updated by #{user.login}")
          else
            n.user = user
          end
          n.save
        end
      end
      result = names.last
    end
    result
  end

  def check_user_id(user_id)
    result = check_permission(user_id)
    unless result
      flash[:notice] = 'Permission denied.'
    end
    result
  end

  def verify_user()
    result = false
    if session['user'].verified.nil?
      redirect_to :controller => 'account', :action=> 'reverify', :id => session['user'].id
    else
      result = true
    end
    result
  end
  # Look in obs_extras.rb for code for uploading directory trees of images.
end
