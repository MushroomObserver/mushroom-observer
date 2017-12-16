class CleanHerbaria < ActiveRecord::Migration
  VALID_CODES = [
    "CANL",
    "CFMR",
    "DBG",
    "ENCB",
    "F",
    "FH",
    "FLOR",
    "NMNHI",
    "NY",
    "OSC",
    "PERTH",
    "PSH",
    "TAN",
    "USJ"
  ]

  def up
    User.current = User.admin

    # Clean out bogus abbreviations -- there is an official registry of these!
    # You cannot just randomly choose to create your own for the fun of it.
    Herbarium.connection.execute(%(
      UPDATE herbaria SET code = ""
      WHERE code NOT IN (#{VALID_CODES.map {|c| "'#{c}'"}.join(",")})
    ))

    # All herbaria must have a unique name!  (Fortunately there are not
    # currently any nonunique names, just this one empty name.)
    Herbarium.connection.execute(%(
      UPDATE herbaria SET name = "someone please fix me!" WHERE name = ""
    ))

    # Somehow HTML formatting ended up getting stored in there for a few.
    Herbarium.connection.select_rows(%(
      SELECT id, name FROM herbaria WHERE name LIKE "%<%"
    )).each do |id, name|
      name.gsub!(/<[<>]*>/, "")
      name = Herbarium.connection.quote(name)
      Herbarium.connection.execute(%(
        UPDATE herbaria SET name = #{name} WHERE id = #{id}
      ))
    end

    # Some names have leading and trailing space, sigh.
    Herbarium.connection.execute(%(
      UPDATE herbaria SET name = TRIM(name)
    ))

    # Try to fill in personal_user_id for those missing it.  Also correct
    # personal herbaria which have the incorrect user. 
    Herbarium.connection.select_rows(%(
      SELECT id, name, personal_user_id FROM herbaria
      WHERE name LIKE "%personal%" OR name LIKE "%personnel%"
    )).each do |id, name, old_user_id|
      match = name.match(/\(([^()]*)\)/)  ||
              name.match(/^(\S.*\S)\s*:/) ||
              next
      user = User.find_by_login(match[1]) ||
             User.find_by_name(match[1])  ||
             next
      if old_user_id.present? && old_user_id != user.id
        old_user = User.safe_find(old_user_id).try(&:login)
        puts "Changing #{old_user.inspect} to #{user.login.inspect} for #{name.inspect}"
      end
      Herbarium.connection.execute(%(
        UPDATE herbaria SET personal_user_id = #{user.id} WHERE id = #{id}
      ))
    end

    # Merge all of a user's personal herbaria if they have multiple.
    Herbarium.connection.select_rows(%(
      SELECT personal_user_id, COUNT(id) FROM herbaria
      WHERE COUNT(id) > 1 GROUP BY personal_user_id
    )).each do |user_id, count|
      user = User.find(user_id)
      puts "#{user.login.inspect} has #{count} herbaria!"
      last_herbarium = nil
      Herbaria.where(personal_user_id: user_id).each do |herbarium|
        if last_herbarium
          puts "Merging #{herbarium.name.inspect} with #{last_herbarium.name.inspect}"
          herbarium = herbarium.merge(last_herbarium)
        end
        last_herbarium = herbarium
      end
    end

    # Remove all curators, then make only personal herbaria have a curator.
    Herbarium.connection.execute(%(
      DELETE FROM herbaria_curators
    ))
    Herbarium.connection.execute(%(
      INSERT INTO herbaria_curators (herbarium_id, user_id) VALUES
      #{ personal_herbaria.map { |h| "(#{h.id},#{h.personal_user_id})" }.join(",") }
    ))
    
    # Remove bogus email from all non-personal herbaria.  In fact remove it
    # from all, because we will provide a default email address for personal
    # herbaria.  That way if the user changes their email address, they won't
    # also have to change their herbarium's email address. 
    Herbarium.connection.execute(%(
      UPDATE herbaria SET email = ""
    ))

    # These are all just garbage -- convert them into notes on herbaria records
    # attached to the user's personal herbarium (creating as necessary).
    [101,626,899,808,442,108,380,268,479,523,508,812,858,578,751,821,420,454,103,788,
     210,516,743,764,765,766,767,768,769,770,771,773,774,775,777,778,781,782,783,784,
     785,786,789,790,791,792,793,794,795,796,797,798,799,800,802,820,822,823,851,763,
     867,772,804,853,635,884,328,299,776,862,214,371,827,681,607,12,533,537,536,737,
     810,434,854,212,213,779,740,729,906,363,203,706,506,860,44,145,816,813,535,462,
     149,343,830,376,831,372,137,856,518,598].each do |id|
      garbage_herbarium = Herbarium.safe_find(id) || next
      comment = garbage_herbarium.name
      HerbariumRecord.where(herbarium_id: id).each do |herbarium_record|
        if herbarium_record.observations.none?
          herbarium_record.destroy
          next
        end
        obs = herbarium_record.observations.first
        personal_herbarium = obs.user.personal_herbarium
        personal_herbarium.save if personal_herbarium.new_record?
        new_notes = comment
        new_notes = "#{herbarium_record.notes}\n#{comment}" if herbarium_record.notes.present?
        herbarium_record.update_attributes(
          herbarium_id: personal_herbarium_id,
          notes: new_notes
        )
      end
      garbage_herbarium.destroy
    end
  end

  def down
  end
end
