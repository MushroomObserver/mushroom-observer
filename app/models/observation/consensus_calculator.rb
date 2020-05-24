class Observation
  class ConsensusCalculator
    attr_reader :debug_messages

    def initialize(namings)
      @namings = namings
      @name_votes  = {}  # Strongest vote for a given name for a user.
      @taxon_votes = {}  # Strongest vote for any names in a group of
      #                    synonyms for a given user.
      @name_ages   = {}  # Oldest date that a name was proposed.
      @taxon_ages  = {}  # Oldest date that a taxon was proposed.
      @user_wgts   = {}  # Caches user rankings.
      @collect_debug_messages = false
    end

    def add_debug_message(message)
      if @collect_debug_messages
        @debug_messages ||= ""
        @debug_messages += message
      end
    end

    # Get the community consensus on what the name should be.  It just
    # adds up the votes weighted by user contribution, and picks the
    # winner.  To break a tie it takes the one with the most votes
    # (again weighted by contribution).  Failing that it takes the
    # oldest one.  Note, it lumps all synonyms together when deciding
    # the winning "taxon", using votes for the separate synonyms only
    # when there are multiple "accepted" names for the winning taxon.
    #
    # Returns Naming instance or nil.  Refreshes vote_cache as a
    # side-effect.
    def calc(debug)
      @collect_debug_messages = debug

      # Gather votes for names and synonyms.  Note that this is
      # trickier than one would expect since it is possible to propose
      # several synonyms for a single observation, and even worse
      # perhaps, one can even propose the very same name multiple
      # times.  Thus a user can potentially vote for a given *name*
      # (not naming) multiple times.  Likewise, of course, for
      # synonyms.  I choose the strongest vote in such cases.
      @namings.each do |naming|
        process_naming(naming)
      end

      # Now that we've weeded out potential duplicate votes, we can combine them
      # safely.
      votes = {}
      @taxon_votes.each_key do |taxon_id|
        vote = votes[taxon_id] = [0, 0]
        @taxon_votes[taxon_id].each_key do |user_id|
          user_vote = @taxon_votes[taxon_id][user_id]
          val = user_vote[0]
          wgt = user_vote[1]
          vote[0] += val * wgt
          vote[1] += wgt
          add_debug_message("vote: taxon_id=#{taxon_id}, " \
                            "user_id=#{user_id}, " \
                            "val=#{val}, wgt=#{wgt}<br/>")
        end
      end

      # Now we can determine the winner among the set of
      # synonym-groups.  (Nathan calls these synonym-groups "taxa",
      # because it better uniquely represents the underlying mushroom
      # taxon, while it might have multiple names.)
      best_val = nil
      best_wgt = nil
      best_age = nil
      best_id  = nil
      votes.each_key do |taxon_id|
        wgt = votes[taxon_id][1]
        val = votes[taxon_id][0].to_f / (wgt + 1.0)
        age = @taxon_ages[taxon_id]
        add_debug_message("#{taxon_id}: " \
                          "val=#{val} wgt=#{wgt} age=#{age}<br/>")
        next unless best_val.nil? ||
                    val > best_val ||
                    val == best_val && (
                      wgt > best_wgt || wgt == best_wgt && (
                        age < best_age
                      )
                    )

        best_val = val
        best_wgt = wgt
        best_age = age
        best_id  = taxon_id
      end
      add_debug_message("best: id=#{best_id}, val=#{best_val}, " \
                        "wgt=#{best_wgt}, age=#{best_age}<br/>")

      # Reverse our kludge that mashed names-without-synonyms and synonym-groups
      # together.  In the end we just want a name.
      if best_id
        best = nil
        match = /^(.)(\d+)/.match(best_id)
        # Synonym id: go through namings and pick first one that belongs to this
        # synonym group.  Any will do for our purposes, because we will convert
        # it to the currently accepted name below.
        if match[1] == "s"
          @namings.each do |naming|
            next if naming.name.synonym_id.to_s != match[2]

            best = naming.name
            break
          end
        else
          best = Name.find(match[2].to_i)
        end
      end
      best_name = best ? best.real_text_name : "nil"
      add_debug_message("unmash: best=#{best_name}<br/>")

      # Now deal with synonymy properly.  If there is a single accepted name,
      # great, otherwise we need to somehow disambiguate.
      if best&.synonym_id
        # This does not allow the community to choose a deprecated synonym over
        # an approved synonym.  See obs #45234 for reasonable-use case.
        # names = best.approved_synonyms
        # names = best.synonyms if names.length == 0
        names = best.synonyms
        if names.length == 1
          best = names.first
        elsif names.length > 1
          synonyms = names.map(&:id).join(", ")
          add_debug_message("Multiple synonyms: #{synonyms}<br>")

          # First combine votes for each name; exactly analagous to what we did
          # with taxa above.
          votes = {}
          @name_votes.each_key do |name_id|
            vote = votes[name_id] = [0, 0]
            @name_votes[name_id].each_key do |user_id|
              user_vote = @name_votes[name_id][user_id]
              val = user_vote[0]
              wgt = user_vote[1]
              vote[0] += val * wgt
              vote[1] += wgt
              add_debug_message("vote: name_id=#{name_id}, " \
                                "user_id=#{user_id}, " \
                                "val=#{val}, wgt=#{wgt}<br/>")
            end
          end

          # Now pick the winner among the ambiguous names.  If none
          # are voted on, just pick the first one (I grow weary of
          # these games).  This latter is all too real of a
          # possibility: users may vigorously debate deprecated names,
          # then at some later date two *new* names are created for
          # the taxon, both are considered "accepted" until the
          # scientific community rules definitively.  Now we have two
          # possible names winning, but no votes on either!  If you
          # have a problem with the one I chose, then vote on the
          # damned thing, already! :)
          best_val2 = nil
          best_wgt2 = nil
          best_age2 = nil
          best_id2  = nil
          names.each do |name|
            name_id = name.id
            vote = votes[name_id]
            next unless vote

            wgt = vote[1]
            val = vote[0].to_f / (wgt + 1.0)
            age = @name_ages[name_id]
            add_debug_message("#{name_id}: val=#{val} wgt=#{wgt} " \
                              "age=#{age}<br/>")
            next unless best_val2.nil? ||
                        val > best_val2 || val == best_val2 && (
                          wgt > best_wgt2 || wgt == best_wgt2 && (
                            age < best_age2
                          )
                        )

            best_val2 = val
            best_wgt2 = wgt
            best_age2 = age
            best_id2  = name_id
          end
          add_debug_message("best: id=#{best_id2}, val=#{best_val2}, " \
                            "wgt=#{best_wgt2}, age=#{best_age2}<br/>")
          best = best_id2 ? Name.find(best_id2) : names.first
        end
      end
      add_debug_message("unsynonymize: " \
                        "best=#{best ? best.real_text_name : "nil"}<br/>")

      # This should only occur for observations created by
      # species_list.construct_observation(), which doesn't necessarily create
      # any votes associated with its naming.  Therefore this should only ever
      # happen when there is a single naming, so there is nothing arbitray in
      # using first.  (I think it can also happen if zero-weighted users are
      # voting.)
      best = @namings.first.name if !best && @namings && !@namings.empty?
      best ||= Name.unknown
      best_name = best ? best.real_text_name : "nil"
      add_debug_message("fallback: best=#{best_name}")

      # Just humor me -- I'm sure there is some pathological case where we can
      # end up after all that work with a misspelt name.
      best = best.correct_spelling if best.correct_spelling

      [best, best_val]
    end

    private

    def process_naming(naming)
      name_id = naming.name_id
      if !@name_ages[name_id] || naming.created_at < @name_ages[name_id]
        @name_ages[name_id] = naming.created_at
      end
      sum_val = 0
      sum_wgt = 0
      # Go through all the votes for this naming.  Should be zero or one per
      # user.
      naming.votes.each do |vote|
        user_id = vote.user_id
        val = vote.value
        wgt = @user_wgts[user_id]
        wgt = @user_wgts[user_id] = vote.user_weight if wgt.nil?
        # It may be possible in the future for us to weight some "special"
        # users zero, who knows...  (It can cause a division by zero below if
        # we ignore zero weights.)
        next unless wgt.positive?

        # Calculate score for naming.vote_cache.
        sum_val += val * wgt
        sum_wgt += wgt
        # Record best vote for this user for this name.  This will be used
        # later to determine which name wins in the case of the winning taxon
        # (see below) having multiple accepted names.
        @name_votes[name_id] = {} unless @name_votes[name_id]
        if !@name_votes[name_id][user_id] ||
           @name_votes[name_id][user_id][0] < val
          @name_votes[name_id][user_id] = [val, wgt]
        end
        # Record best vote for this user for this group of synonyms.  (Since
        # not all taxa have synonyms, I've got to create a "fake" id that
        # uses the synonym id if it exists, else uses the name id, but still
        # keeps them separate.)
        taxon_id = if naming.name.synonym_id
                     "s" + naming.name.synonym_id.to_s
                   else
                     "n" + name_id.to_s
                   end
        if !@taxon_ages[taxon_id] ||
           naming.created_at < @taxon_ages[taxon_id]
          @taxon_ages[taxon_id] = naming.created_at
        end
        @taxon_votes[taxon_id] = {} unless @taxon_votes[taxon_id]
        add_debug_message("raw vote: taxon_id=#{taxon_id}, " \
                          "name_id=#{name_id}, " \
                          "user_id=#{user_id}, " \
                          "val=#{val}<br/>")
        if !@taxon_votes[taxon_id][user_id] ||
           @taxon_votes[taxon_id][user_id][0] < val
          @taxon_votes[taxon_id][user_id] = [val, wgt]
        end
      end
      cache_value = sum_wgt.positive? ? sum_val.to_f / (sum_wgt + 1.0) : 0.0
      update_naming_cache(naming, cache_value)
    end

    def update_naming_cache(naming, value)
      if naming.vote_cache != value
        naming.vote_cache = value
        naming.save
      end
    end
  end
end
