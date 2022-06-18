module Users
  # Controls viewing and modifying users by admins.
  class BonusesController < ApplicationController
    # filters
    before_action :login_required
    before_action :pass_query_params
    before_action :keep_track_of_referrer

    # Old MO Action (method)                  New "Normalized" Action (method)
    # ----------------------------            --------------------------------
    # observer_change_user_bonuses (get)      Users::Bonus#new (get)
    # observer_change_user_bonuses (post)     Users::Bonus#create (post)

    # Admin util linked from show page that lets admin add or change bonuses
    # for a given user.
    def new
      return unless (@user2 = find_or_goto_index(User, params[:id].to_s))

      redirect_to(action: "show", id: @user2.id) unless in_admin_mode?

      # Reformat bonuses as string for editing, one entry per line.
      @val = ""
      if @user2.bonuses
        vals = @user2.bonuses.map do |points, reason|
          format("%-6d %s", points, reason.gsub(/\s+/, " "))
        end
        @val = vals.join("\n")
      end
    end

    def create
      return unless (@user2 = find_or_goto_index(User, params[:id].to_s))

      redirect_to(action: "show", id: @user2.id) unless in_admin_mode?

      # Parse new set of values.
      @val = params[:val]
      line_num = 0
      errors = false
      bonuses = []
      @val.split("\n").each do |line|
        line_num += 1
        if (match = line.match(/^\s*(\d+)\s*(\S.*\S)\s*$/))
          bonuses.push([match[1].to_i, match[2].to_s])
        else
          flash_error("Syntax error on line #{line_num}.")
          errors = true
        end
      end
      # Success: update user's contribution.
      unless errors
        contrib = @user2.contribution.to_i
        # Subtract old bonuses.
        @user2.bonuses&.each_key do |points|
          contrib -= points
        end
        # Add new bonuses
        bonuses.each do |(points, _reason)|
          contrib += points
        end
        # Update database.
        @user2.bonuses      = bonuses
        @user2.contribution = contrib
        @user2.save
        redirect_to(action: "show", id: @user2.id)
      end
    end
  end
end
