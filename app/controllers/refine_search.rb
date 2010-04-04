#
#  = Refine Search
#
#  Controller mix-in used by ObserverController for observer/refine_search.
#
################################################################################

module RefineSearch

  ################################################################################
  #
  #  :section: Initialize form
  #
  ################################################################################

  # Get Array of conditions that the user can use to narrow their search.
  def refine_search_get_fields(query)
    results = []

    # Various pulldowns used below.
    boolean = [ [:refine_search_yes.l, '1'], [:refine_search_no.l, '0'] ]
    only_no = [ [:refine_search_no.l, '0'] ]
    only_yes = [ [:refine_search_yes.l, '1'] ]
    confidence = translate_menu(Vote.confidence_menu)
    quality = Image.all_votes.reverse.map {|v| [:"image_vote_long_#{v}".l, v]}
    ranks = Name.all_ranks.reverse.map {|r| ["rank_#{r}".upcase.to_sym.l, r]}
    licenses = License.current_names_and_ids.map {|l,v| [l.sub(/Creative Commons/,'CC'), v]}

    # ----------------------------
    #  Comment conditions.
    # ----------------------------

    case query.model_symbol
    when :Comment
      types = [
        [:OBSERVATION.t, :observation],
        [:NAME.t, :name],
        [:LOCATION.t, :location],
      ]
      results << {
        :name  => :object_type,
        :label => :refine_search_object_type.t,
        :input => :enum,
        :opts  => types,
        :type  => :equal,
        :field => 'comments.object_type',
      }
      results << {
        :name  => :object_id,
        :label => :refine_search_object_id.t,
        :input => :string,
        :type  => :equal,
        :field => 'comments.object_id',
      }
      results << {
        :name  => :summary,
        :label => :refine_search_contains.t(:type => :summary),
        :input => :string,
        :type  => :like,
        :field => 'comments.summary',
      }
      results << {
        :name  => :comment,
        :label => :refine_search_contains.t(:type => :comment),
        :input => :string,
        :type  => :like,
        :field => 'comments.comment',
      }
      results << {
        :name  => :user,
        :label => :refine_search_created_by.t,
        :input => :string,
        :autocomplete => :user,
        :type  => :lookup,
        :model => User,
        :field => 'comments.user_id',
      }
      results << {
        :name  => :user,
        :label => :refine_search_comment_for.t,
        :input => :string,
        :autocomplete => :user,
        :type  => :lookup,
        :model => User,
        :join  => :observations,
        :field => 'observations.user_id',
      }
      results << {
        :name  => :created,
        :label => :refine_search_created_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'comments.created',
      }
      results << {
        :name  => :modified,
        :label => :refine_search_last_modified_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'comments.modified',
      }

    # ----------------------------
    #  Image conditions.
    # ----------------------------

    when :Image
      content_types = Image.all_content_types
      extensions    = Image.all_extensions
      types_menu = []
      content_types.each_index do |i|
        if content_type = content_types[i]
          types_menu << ["*.#{extensions[i]}", content_type]
        end
      end
      results << {
        :name  => :name,
        :label => :refine_search_name.t,
        :input => :string,
        :autocomplete => :name,
        :type  => :lookup,
        :model => Name,
        :join  => '{:images_observations => :observations}',
        :field => 'observations.name_id',
      }
      results << {
        :name  => :synonym,
        :label => :refine_search_synonym.t,
        :input => :string,
        :autocomplete => :name,
        :type  => :lookup,
        :model => Name,
        :method => :synonym_ids,
        :join  => '{:images_observations => :observations}',
        :field => 'observations.name_id',
      }
      results << {
        :name  => :child,
        :label => :refine_search_child.t,
        :input => :string,
        :autocomplete => :name,
        :type  => :lookup,
        :model => Name,
        :method => :all_children,
        :join  => '{:images_observations => :observations}',
        :field => 'observations.name_id',
      }
      results << {
        :name  => :location,
        :label => :refine_search_contains.t(:type => :location),
        :input => :string,
        :autocomplete => :location,
        :type  => :like,
        :join  => '{:images_observations => {:observations => :locations!}}',
        :field => 'IF(locations.id,locations.search_name,observations.where)',
      }
      results << {
        :name  => :has_votes,
        :label => :refine_search_has.t(:type => :votes),
        :input => :enum,
        :opts  => boolean,
        :type  => :is_not_null,
        :field => 'images.vote_cache',
      }
      results << {
        :name  => :minimum_quality,
        :label => :refine_search_minimum_quality.t,
        :input => :enum,
        :opts  => quality,
        :type  => :at_least,
        :field => 'images.vote_cache',
      }
      results << {
        :name  => :minimum_size,
        :label => :refine_search_minimum_size.t,
        :input => :string,
        :type  => :at_least,
        :field => 'IF(images.width<images.height,images.width,images.height)',
      }
      results << {
        :name  => :has_notes,
        :label => :refine_search_has.t(:type => :notes),
        :input => :enum,
        :opts  => boolean,
        :type  => :nonblank,
        :field => 'images.notes',
      }
      results << {
        :name  => :notes,
        :label => :refine_search_contains.t(:type => :notes),
        :input => :string,
        :type  => :like,
        :field => 'images.notes',
      }
      results << {
        :name  => :content_type,
        :label => :refine_search_original_type.t,
        :input => :enum,
        :opts  => types_menu,
        :type  => :equal,
        :field => 'images.content_type',
      }
      results << {
        :name  => :license_id,
        :label => :refine_search_license.t,
        :input => :enum,
        :opts  => licenses,
        :type  => :equal,
        :field => 'images.license_id',
      }
      results << {
        :name  => :user,
        :label => :refine_search_posted_by.t,
        :input => :string,
        :autocomplete => :user,
        :type  => :lookup,
        :model => User,
        :field => 'images.user_id',
      }
      results << {
        :name  => :copyright_holder,
        :label => :refine_search_contains.t(:type => :copyright_holder),
        :input => :string,
        :autocomplete => :user,
        :type  => :like,
        :clean_value => lambda do |val|
          val.match(/<(.*)>/) ? $1 : val
        end,
        :field => 'images.copyright_holder',
      }
      results << {
        :name  => :date,
        :label => :refine_search_date.t,
        :input => :string,
        :help  => :refine_search_date_help.l,
        :type  => :date,
        :field => 'images.when',
      }
      results << {
        :name  => :created,
        :label => :refine_search_created_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'images.created',
      }
      results << {
        :name  => :modified,
        :label => :refine_search_last_modified_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'images.modified',
      }

    # ----------------------------
    #  Name conditions.
    # ----------------------------

    when :Name
      results << {
        :name  => :rank,
        :label => :refine_search_rank.t,
        :input => :enum,
        :opts  => ranks,
        :type  => :equal,
        :field => 'names.rank',
      }
      results << {
        :name  => :rank,
        :label => :refine_search_above_rank.t,
        :input => :enum,
        :opts  => ranks,
        :type  => :above_rank,
        :field => 'names.rank',
      }
      results << {
        :name  => :rank,
        :label => :refine_search_below_rank.t,
        :input => :enum,
        :opts  => ranks,
        :type  => :below_rank,
        :field => 'names.rank',
      }
      results << {
        :name  => :name,
        :label => :refine_search_contains.t(:type => :name),
        :input => :string,
        :autocomplete => :name,
        :type  => :like,
        :field => 'names.search_name',
      }
      results << {
        :name  => :has_author,
        :label => :refine_search_has.t(:type => :authority),
        :input => :enum,
        :opts  => boolean,
        :type  => :nonblank,
        :field => 'names.author',
      }
      results << {
        :name  => :author,
        :label => :refine_search_contains.t(:type => :authority),
        :input => :string,
        :type  => :like,
        :field => 'names.author',
      }
      results << {
        :name  => :has_citation,
        :label => :refine_search_has.t(:type => :citation),
        :input => :enum,
        :opts  => boolean,
        :type  => :nonblank,
        :field => 'names.citation',
      }
      results << {
        :name  => :citation,
        :label => :refine_search_contains.t(:type => :citation),
        :input => :string,
        :type  => :like,
        :field => 'names.citation',
      }
      results << {
        :name  => :has_notes,
        :label => :refine_search_has.t(:type => :notes),
        :input => :enum,
        :opts  => boolean,
        :type  => :nonblank,
        :field => 'names.notes',
      }
      results << {
        :name  => :notes,
        :label => :refine_search_contains.t(:type => :notes),
        :input => :string,
        :type  => :like,
        :field => 'names.notes',
      }
      results << {
        :name  => :has_classification,
        :label => :refine_search_has.t(:type => :refine_search_classification),
        :input => :enum,
        :opts  => boolean,
        :type  => :nonblank,
        :field => 'names.classification',
      }
      results << {
        :name  => :classification,
        :label => :refine_search_contains.t(:type => :refine_search_classification),
        :input => :string,
        :type  => :like,
        :field => 'names.classification',
      }
      results << {
        :name  => :is_deprecated,
        :label => :refine_search_deprecated.t,
        :input => :enum,
        :opts  => boolean,
        :type  => :is_true,
        :field => 'names.deprecated',
      }
      results << {
        :name  => :is_misspelled,
        :label => :refine_search_misspelled.t,
        :input => :enum,
        :opts  => boolean,
        :type  => :is_not_null,
        :field => 'names.correct_spelling_id',
      }
      results << {
        :name  => :has_synonyms,
        :label => :refine_search_has.t(:type => :synonyms),
        :input => :enum,
        :opts  => boolean,
        :type  => :is_not_null,
        :field => 'names.synonym_id',
      }
      results << {
        :name  => :is_synonym,
        :label => :refine_search_synonym.t,
        :input => :string,
        :autocomplete => :name,
        :type  => :lookup,
        :model => Name,
        :method => :synonym_ids,
        :field => 'names.id',
      }
      results << {
        :name  => :is_misspelling,
        :label => :refine_search_misspelling.t,
        :input => :string,
        :autocomplete => :name,
        :type  => :lookup,
        :model => Name,
        :method => :misspelling_ids,
        :field => 'names.id',
      }
      results << {
        :name  => :is_child,
        :label => :refine_search_child.t,
        :input => :string,
        :autocomplete => :name,
        :type  => :lookup,
        :model => Name,
        :method => :all_children,
        :field => 'names.id',
      }
      results << {
        :name  => :has_description,
        :label => :refine_search_has.t(:type => :description),
        :input => :enum,
        :opts  => only_yes,
        :type  => :just_join,
        :join  => :name_descriptions,
      }
      results << {
        :name  => :has_default_description,
        :label => :refine_search_has_default_description.t,
        :input => :enum,
        :opts  => boolean,
        :type  => :is_not_null,
        :field => 'names.description_id',
      }
      # Not sure how to allow for negative here -- requires grouping?
      results << {
        :name  => :has_public_description,
        :label => :refine_search_has_public_description.t,
        :input => :enum,
        :opts  => only_yes,
        :type  => :is_true,
        :join  => :name_descriptions,
        :field => 'name_descriptions.public',
      }
      # Not sure how to allow for negative here -- requires grouping?
      results << {
        :name  => :has_draft,
        :label => :refine_search_has.t(:type => :draft),
        :input => :enum,
        :opts  => only_yes,
        :type  => :boolean,
        :yes   => 'name_descriptions.source_type = "draft"',
      }
      results << {
        :name  => :user,
        :label => :refine_search_created_by.t,
        :input => :string,
        :autocomplete => :user,
        :type  => :lookup,
        :model => User,
        :field => 'names.user_id',
      }
      results << {
        :name  => :user,
        :label => :refine_search_modified_by.t,
        :input => :string,
        :autocomplete => :user,
        :type  => :lookup,
        :model => User,
        :join  => :names_versions,
        :field => 'names_versions.user_id',
      }
      results << {
        :name  => :created,
        :label => :refine_search_created_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'names.created',
      }
      results << {
        :name  => :modified,
        :label => :refine_search_last_modified_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'names.modified',
      }

    # ----------------------------
    #  Observation conditions.
    # ----------------------------

    when :Observation
      results << {
        :name  => :name,
        :label => :refine_search_name.t,
        :input => :string,
        :autocomplete => :name,
        :type  => :lookup,
        :model => Name,
        :field => 'observations.name_id',
      }
      results << {
        :name  => :synonym,
        :label => :refine_search_synonym.t,
        :input => :string,
        :autocomplete => :name,
        :type  => :lookup,
        :model => Name,
        :method => :synonym_ids,
        :field => 'observations.name_id',
      }
      results << {
        :name  => :child,
        :label => :refine_search_child.t,
        :input => :string,
        :autocomplete => :name,
        :type  => :lookup,
        :model => Name,
        :method => :all_children,
        :field => 'observations.name_id',
      }
      results << {
        :name  => :location,
        :label => :refine_search_contains.t(:type => :location),
        :input => :string,
        :autocomplete => :location,
        :type  => :like,
        :join  => :locations!,
        :field => 'IF(locations.id,locations.search_name,observations.where)',
      }
      results << {
        :name  => :location_defined,
        :label => :refine_search_location_defined.t,
        :input => :enum,
        :opts  => boolean,
        :type  => :is_not_null,
        :field => 'observations.location_id',
      }
      results << {
        :name  => :user,
        :label => :refine_search_created_by.t,
        :input => :string,
        :autocomplete => :user,
        :type  => :lookup,
        :model => User,
        :field => 'observations.user_id',
      }
      results << {
        :name  => :posted,
        :label => :refine_search_date.t,
        :input => :string,
        :help  => :refine_search_date_help.l,
        :type  => :date,
        :field => 'observations.when',
      }
      results << {
        :name  => :created,
        :label => :refine_search_created_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'observations.created',
      }
      results << {
        :name  => :modified,
        :label => :refine_search_last_modified_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'observations.modified',
      }
      results << {
        :name  => :has_votes,
        :label => :refine_search_has.t(:type => :votes),
        :input => :enum,
        :opts  => boolean,
        :type  => :is_not_null,
        :field => 'observations.vote_cache',
      }
      results << {
        :name  => :min_confidence,
        :label => :refine_search_minimum_confidence.t,
        :input => :enum,
        :opts  => confidence,
        :type  => :at_least,
        :field => 'observations.vote_cache',
      }
      results << {
        :name  => :max_confidence,
        :label => :refine_search_maximum_confidence.t,
        :input => :enum,
        :opts  => confidence,
        :type  => :at_most,
        :field => 'observations.vote_cache',
      }
      results << {
        :name  => :has_images,
        :label => :refine_search_has.t(:type => :images),
        :input => :enum,
        :opts  => boolean,
        :type  => :is_not_null,
        :field => 'observations.thumb_image_id',
      }
      results << {
        :name  => :has_minimum_image_quality,
        :label => :refine_search_has_image_of_min_quality.t,
        :input => :enum,
        :opts  => quality,
        :type  => :at_least,
        :join  => '{:images_observations => :images}',
        :field => 'images.vote_cache',
      }
      results << {
        :name  => :has_species_lists,
        :label => :refine_search_has_species_list.t,
        :input => :enum,
        :opts  => only_yes,
        :type  => :just_join,
        :join  => :observations_species_lists
      }
      results << {
        :name  => :species_list,
        :label => :refine_search_in_species_list.t,
        :input => :string,
        :autocomplete => :species_list,
        :type  => :lookup,
        :model => SpeciesList,
        :field => 'observations.user_id',
      }
      results << {
        :name  => :specimen,
        :label => :refine_search_has_specimen.t,
        :input => :enum,
        :opts  => boolean,
        :type  => :is_true,
        :field => 'observations.specimen',
      }
      results << {
        :name  => :is_collection_location,
        :label => :refine_search_is_collection_location.t,
        :input => :enum,
        :opts  => boolean,
        :type  => :is_true,
        :field => 'observations.is_collection_location',
      }
      results << {
        :name  => :has_notes,
        :label => :refine_search_has.t(:type => :notes),
        :input => :enum,
        :opts  => boolean,
        :type  => :nonblank,
        :field => 'observations.notes',
      }
      results << {
        :name  => :notes,
        :label => :refine_search_contains.t(:type => :notes),
        :input => :string,
        :type  => :like,
        :field => 'observations.notes',
      }
      results << {
        :name  => :has_comments,
        :label => :refine_search_has.t(:type => :comments),
        :input => :enum,
        :opts  => only_yes,
        :type  => :just_join,
        :join  => :comments,
      }
      results << {
        :name  => :comments,
        :label => :refine_search_contains.t(:type => :comments),
        :input => :string,
        :type  => :like,
        :join  => :comments,
        :field => 'CONCAT(comments.summary,comments.comment)',
      }

    # ----------------------------
    #  Project conditions.
    # ----------------------------

    when :Project
      results << {
        :name  => :title,
        :label => :refine_search_contains.t(:type => :title),
        :input => :string,
        :type  => :like,
        :field => 'projects.title',
      }
      results << {
        :name  => :summary,
        :label => :refine_search_contains.t(:type => :summary),
        :input => :string,
        :type  => :like,
        :field => 'projects.summary',
      }
      results << {
        :name  => :created,
        :label => :refine_search_created_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'projects.created',
      }
      results << {
        :name  => :modified,
        :label => :refine_search_last_modified_on.t,
        :input => :string,
        :help  => :refine_search_time_help.l,
        :type  => :time,
        :field => 'projects.modified',
      }
      results << {
        :name  => :user,
        :label => :refine_search_created_by.t,
        :input => :string,
        :autocomplete => :user,
        :type  => :lookup,
        :model => User,
        :field => 'projects.user_id',
      }
      if !query.uses_join?('user_groups')
        results << {
        :name  => :admin,
        :label => :refine_search_has_admin.t,
        :input => :string,
          :type  => :lookup,
          :model => User,
          :join  => :'user_groups.admin_group',
          :field => 'user_groups.user_id',
        }
      end
      if !query.uses_join?('user_groups.admin_group')
        results << {
        :name  => :member,
        :label => :refine_search_has_member.t,
        :input => :string,
          :type  => :lookup,
          :model => User,
          :join  => :user_groups,
          :field => 'user_groups.user_id',
        }
      end

    # when :Location
    # when :LocationDescription
    # when :NameDescription
    # when :RssLog
    # when :SpeciesList
    # when :User
    end

    # Temporarily remove fields I haven't implemented.
    # results = results.select do |field|
    #   respond_to?("refine_search_#{field[:type]}")
    # end

    results = nil if results.empty?
    return results
  end

  ################################################################################
  #
  #  :section: Modify query
  #
  ################################################################################

  # Apply one or more additional conditions to the query.
  def refine_search_apply_changes(query, fields, conds)
    any_changes = false
    any_errors  = false
    params = query.params.dup
    query.extend_join(params)
    query.extend_where(params)

    # Remove any un-checked existing conditions.
    i = 0
    new_wheres = []
    for cond in params[:where]
      i += 1
      if conds.send("old_#{i}") == '1'
        new_wheres << cond
      else
        any_changes = true
      end
    end
    params[:where] = new_wheres

    # Translate form fields into join/where conditions which are added to the
    # existing query parameters.
    for field in fields
      val = conds.send(field[:name])
      if !val.blank?
        if field[:clean_value]
          val = field[:clean_value].call(val)
        end
        if !val.blank?
          if field[:join] && !params[:join].include?(field[:join])
            params[:join] << field[:join]
          end
          begin
            send("refine_search_#{field[:type]}", query, params, val, field)
            any_changes = true
          rescue => e
            flash_error(e)
            any_errors = true
          end
        end
      end
    end

    params.delete(:join)  if params[:join] == []
    params.delete(:where) if params[:where] == []

    # Create and initialize the new query to test it out.  If this succeeds,
    # we will send the user back to the index to see the new results.
    result = nil
    if any_errors
      # Already flashed errors when they occurred.
    elsif !any_changes
      flash_error(:runtime_no_conditions.t) if !@goto_index
    else
      begin
        query2 = Query.lookup(query.model, query.flavor, params)
        query2.initialize_query
        query2.save
        result = query2
      rescue => e
        flash_error(e)
      end
    end

    # Return new query if changes made successfully, otherwise we'll make all
    # the changes again next time.
    return result
  end

  ################################################################################
  #
  #  :section: Apply new conditions
  #
  ################################################################################

  def refine_search_just_join(query, params, val, args)
    # Join is done by the caller.
  end

  def refine_search_boolean(query, params, val, args)
    params[:where] << (val == '1') ? args[:yes] : args[:no]
  end

  def refine_search_is_not_null(query, params, val, args)
    params[:where] << (val == '1' ?
      "#{args[:field]} IS NOT NULL" :
      "#{args[:field]} IS NULL")
  end

  def refine_search_is_null(query, params, val, args)
    params[:where] << (val == '1' ?
      "#{args[:field]} IS NULL" :
      "#{args[:field]} IS NOT NULL")
  end

  def refine_search_is_true(query, params, val, args)
    params[:where] << (val == '1' ?
      "#{args[:field]} IS TRUE" :
      "#{args[:field]} IS FALSE")
  end

  def refine_search_is_false(query, params, val, args)
    params[:where] << (val == '1' ?
      "#{args[:field]} IS FALSE" :
      "#{args[:field]} IS TRUE")
  end

  def refine_search_nonblank(query, params, val, args)
    params[:where] << (val == '1' ?
      "LENGTH(#{args[:field]}) > 0" :
      "NOT (LENGTH(#{args[:field]}) > 0)")
  end

  def refine_search_blank(query, params, val, args)
    params[:where] << (val == '1' ?
      "NOT (LENGTH(#{args[:field]}) > 0)" :
      "LENGTH(#{args[:field]}) > 0")
  end

  def refine_search_equal(query, params, val, args)
    params[:where] << "#{args[:field]} = #{query.escape(val)}"
  end

  def refine_search_at_least(query, params, val, args)
    params[:where] << "#{args[:field]} >= #{query.escape(val)}"
  end

  def refine_search_more_than(query, params, val, args)
    params[:where] << "#{args[:field]} > #{query.escape(val)}"
  end

  def refine_search_at_most(query, params, val, args)
    params[:where] << "#{args[:field]} <= #{query.escape(val)}"
  end

  def refine_search_less_than(query, params, val, args)
    params[:where] << "#{args[:field]} < #{query.escape(val)}"
  end

  def refine_search_like(query, params, val, args)
    params[:where] << "#{args[:field]} LIKE '%#{query.clean_pattern(val)}%'"
  end

  def refine_search_above_rank(query, params, val, args)
    ranks = Name.all_ranks
    if idx = ranks.idx(val.to_sym)
      ranks = ranks[idx+1..-1].map {|v| query.escape(v)}.join(',')
      params[:where] << "#{args[:field]} IN (#{ranks})"
    else
      raise "Invalid rank: #{val.inspect}"
    end
  end

  def refine_search_below_rank(query, params, val, args)
    ranks = Name.all_ranks
    if (idx = ranks.idx(val.to_sym)) > 0
      ranks = ranks[0..idx-1].map {|v| query.escape(v)}.join(',')
      params[:where] << "#{args[:field]} IN (#{ranks})"
    else
      raise "Invalid rank: #{val.inspect}"
    end
  end

  def refine_search_date(query, params, val, args)
    f = args[:field]
    val = val.to_s.strip_squeeze
    unless val.match(/^(\d\d\d\d)((-)(\d\d\d\d))$/) or
           val.match(/^([a-z]\w+)((-)([a-z]\w+))$/i) or
           val.match(/^([\w\-]+)( (- |to |a )?([\w\-]+))?$/)
      raise :runtime_invalid.t(:type => :date, :value => val)
    end
    date1, date2 = $1, $4
    y1, m1, d1 = refine_search_parse_date(date1)
    if date2
      y2, m2, d2 = refine_search_parse_date(date2)
      if (!!y1 != !!y2) or (!!m1 != !!m2) or (!!d1 != !!d2)
        raise :runtime_dates_must_be_same_format.t
      end

      # Two full dates.
      if y1
        params[:where] << "#{f} >= '%04d-%02d-%02d' AND #{f} <= '%04d-%02d-%02d'" % [y1, m1 || 1, d1 || 1, y2, m2 || 12, d2 || 31]

      # Two months and days.
      elsif d1
        if "#{m1}#{d1}".to_i < "#{m2}#{d2}".to_i
          params[:where] << "(MONTH(#{f}) > #{m1} OR MONTH(#{f}) = #{m1} AND DAY(#{f}) >= #{d1}) AND (MONTH(#{f}) < #{m2} OR MONTH(#{f}) = #{m2} AND DAY(#{f}) <= #{d2})"
        else
          params[:where] << "MONTH(#{f}) > #{m1} OR MONTH(#{f}) = #{m1} AND DAY(#{f}) >= #{d1} OR MONTH(#{f}) < #{m2} OR MONTH(#{f}) = #{m2} AND DAY(#{f}) <= #{d2}"
        end

      # Two months.
      else
        if m1 < m2
          params[:where] << "MONTH(#{f}) >= #{m1} AND MONTH(#{f}) <= #{m2}"
        else
          params[:where] << "MONTH(#{f}) >= #{m1} OR MONTH(#{f}) <= #{m2}"
        end
      end

    # One full date.
    elsif y1 && m1 && d1
      params[:where] << "#{f} = '%04d-%02d-%02d'" % [y1, m1, d2]
    elsif y1 && m1
      params[:where] << "YEAR(#{f}) = #{y1} AND MONTH(#{f}) = #{m1}"
    elsif y1
      params[:where] << "YEAR(#{f}) = #{y1}"

    # One month (and maybe day).
    elsif d1
      params[:where] << "MONTH(#{f}) = #{m1} AND DAY(#{f}) = #{d1}"
    else
      params[:where] << "MONTH(#{f}) = #{m1}"
    end
  end

  def refine_search_time(query, params, val, args)
    f = args[:field]
    val = val.to_s.strip_squeeze
    if !val.match(/^([\w\-\:]+)( (- |to |a )?([\w\-\:]+))?$/)
      raise :runtime_invalid.t(:type => :date, :value => val)
    end
    date1, date2 = $1, ($4 || $1)
    y1, m1, d1, h1, n1, s1 = refine_search_parse_time(date1)
    y2, m2, d2, h2, n2, s2 = refine_search_parse_time(date2)
    m1 ||=  1; d1 ||=  1; h1 ||=  0; n1 ||=  0; s1 ||=  0
    m2 ||= 12; d2 ||= 31; h2 ||= 23; n2 ||= 59; s2 ||= 59
    params[:where] << "#{f} >= '%04d-%02d-%02d %02d:%02d:%02d' AND #{f} <= '%04d-%02d-%02d %02d:%02d:%02d'" % [y1, m1, d1, h1, n1, s1, y2, m2, d2, h2, n2, s2]
  end

  def refine_search_parse_date(str)
    y = m = d = nil
    if str.match(/^(\d\d\d\d)(-(\d\d|[a-z]{3,}))?(-(\d\d))?$/i)
      y, m, d = $1, $3, $5
      if m && m.length > 2
        m = :date_helper_month_names.l.index(m) ||
            :date_helper_abbr_month_names.l.index(m)
      end
    elsif str.match(/^(\d\d|[a-z]{3,})(-(\d\d))?$/i)
      m, d = $1, $3
      m = refine_search_parse_month(m) if m && m.length > 2
    else
      raise :runtime_invalid.t(:type => :date, :value => str)
    end
    return [y, m, d].map {|x| x && x.to_i}
  end

  def refine_search_parse_time(str)
    if !str.match(/^(\d\d\d\d)(-(\d\d|[a-z]{3,}))?(-(\d\d))?(:(\d\d))?(:(\d\d))?(:(\d\d))?(am|pm)?$/i)
      raise :runtime_invalid.t(:type => :date, :value => str)
    end
    y, m, d, h, n, s, am = $1, $3, $5, $7, $9, $11, $12
    if m && m.length > 2
      m = :date_helper_month_names.l.index(m) ||
          :date_helper_abbr_month_names.l.index(m)
    end
    h = h.to_i + 12 if h && am && am.downcase == 'pm'
    return [y, m, d, h, n, s].map {|x| x && x.to_i}
  end

  def refine_search_parse_month(str)
    result = nil
    str = str.downcase
    for list in [
      :date_helper_month_names.l,
      :date_helper_abbr_month_names.l
    ]
      result = list.map {|v| v.is_a?(String) && v.downcase }.index(str)
      break if result
    end
    return result
  end

  def refine_search_lookup(query, params, val, args)
    model = args[:model]
    type = model.name.underscore.to_sym
    val = val.to_s.strip_squeeze
    ids = objs = nil

    # Supplied one or more ids.
    if val.match(/^\d+(,? ?\d+)*$/)
      ids = val.split(/[, ]+/).map(&:to_i)
      if args[:method]
        objs = model.all(:conditions => ['id IN (?)', ids])
      end

    # Supplied full or partial string.
    else
      case type
      when :name
        objs = model.find_all_by_search_name(val)
        objs = model.find_all_by_text_name(val) if objs.empty?
        if objs.empty?
          val  = query.clean_pattern(val)
          objs = model.all(:conditions => "search_name LIKE '#{val}%'")
        end
      when :species_list
        objs = model.find_all_by_title(val)
        if objs.empty?
          val  = query.clean_pattern(val)
          objs = model.all(:conditions => "title LIKE '#{val}%'")
        end
      when :user
        val.sub!(/ *<.*>/, '')
        objs = model.find_all_by_login(val)
        objs = model.find_all_by_name(val) if objs.empty?
        if objs.empty?
          val  = query.clean_pattern(val)
          objs = model.all(:conditions => "login LIKE '#{val}%' OR name LIKE '#{val}%'")
        end
      else
        raise "Unsupported model in lookup condition: #{args[:model].name.inspect}"
      end
    end

    if objs && objs.empty?
      raise :runtime_no_matches.t(:type => type)
    end

    # Call an additional method on each result?
    if method = args[:method]
      if !objs.first.respond_to?(method)
        raise "Invalid :method for lookup condition: #{method.inspect}"
      end
      if method.to_s.match(/_ids$/)
        ids = objs.map(&method).flatten
      else
        ids = objs.map(&method).flatten.map(&:id)
      end
    elsif objs
      ids = objs.map(&:id)
    end

    # Put together final condition.
    ids = ids.uniq.map(&:to_s).join(',')
    params[:where] << "#{args[:field]} IN (#{ids})"
  end
end
