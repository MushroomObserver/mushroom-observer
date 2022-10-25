# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :login_required

    ### Custom login_required behavior for this controller

    def authorize?(_user)
      in_admin_mode?
    end

    def access_denied
      flash_error(:permission_denied.t)
      if params[:id]
        redirect_to(user_path(id: params[:id]))
      else
        redirect_to(users_path)
      end
    end

    ###

    ### Edit user bonuses

    def edit
      return unless (@user2 = find_or_goto_index(User, params[:id].to_s))

      # Reformat bonuses as string for editing, one entry per line.
      @val = if @user2.bonuses
               vals = @user2.bonuses.map do |points, reason|
                 format("%<points>-6d %<reason>s",
                        points: points, reason: reason.gsub(/\s+/, " "))
               end
               vals.join("\n")
             else
               ""
             end
    end

    def update
      return unless (@user2 = find_or_goto_index(User, params[:id].to_s))

      # Parse new set of values.
      @val = params[:val]
      bonuses = calculate_bonuses
      return if bonuses.nil?

      update_user_contribution(bonuses)
      redirect_to(user_path(@user2.id))
    end

    # Delete user. This is messy, but the new User#erase_user method
    # makes a pretty good stab at the problem.
    def destroy
      id = params["id"]
      if id.present?
        user = User.safe_find(id)
        User.erase_user(id) if user
      end
      redirect_back_or_default("/")
    end

    private

    def calculate_bonuses
      line_num = 0
      bonuses = []
      @val.split("\n").each do |line|
        line_num += 1
        if (match = line.match(/^\s*(\d+)\s*(\S.*\S)\s*$/))
          bonuses.push([match[1].to_i, match[2].to_s])
        else
          flash_error("Syntax error on line #{line_num}.")
          return nil
        end
      end
      bonuses
    end

    def update_user_contribution(bonuses)
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
    end
  end
end
