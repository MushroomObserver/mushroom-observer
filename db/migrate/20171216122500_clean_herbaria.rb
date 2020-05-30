require "extensions.rb"

class CleanHerbaria < ActiveRecord::Migration[4.2]
  VALID_CODES = [
    "",
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
    Herbarium.where.not(code: VALID_CODES).each do |herbarium|
      puts "Removing code #{herbarium.code.inspect} from #{herbarium.name.inspect}"
      herbarium.update_columns(code: "")
    end

    # Somehow HTML formatting ended up getting stored in there for a few.
    Herbarium.where("name LIKE '%<%'").each do |herbarium|
      new_name = herbarium.name.gsub(/<[^<>]*>/, "")
      puts "Removing HTML tags from #{herbarium.name.inspect}"
      herbarium.update_columns(name: new_name)
    end

    # Some names have leading and trailing space, sigh.
    Herbarium.where("name LIKE ' %' OR name LIKE '%  %' OR name LIKE '% '").each do |herbarium|
      new_name = herbarium.name.gsub(/\s\s+/, " ").gsub(/^\s+|\s+$/, "")
      puts "Removing excess white space from #{herbarium.name.inspect}"
      herbarium.update_columns(name: new_name)
    end

    # Make sure there are no reused herbarium names.
    Herbarium.connection.select_rows(%(
      SELECT name, COUNT(id) FROM herbaria GROUP BY name
    )).each do |name, count|
      next if count == 1
      puts "Merging #{count} herbaria with the name #{name.inspect}"
      last_herbarium = nil
      Herbarium.where(name: name).each do |herbarium|
        if last_herbarium
          puts "Merging #{herbarium.id} with #{last_herbarium.id}"
          herbarium = herbarium.merge(last_herbarium)
        end
        last_herbarium = herbarium
      end
    end

    # Try to fill in personal_user_id for those missing it.  Also correct
    # personal herbaria which have the incorrect user.
    puts "Making users owner of their own herbarium."
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
        puts "Making #{user.login.inspect} owner of #{name.inspect} (was #{old_user.inspect})"
      end
      Herbarium.find(id).update_columns(personal_user_id: user.id)
    end

    # Merge all of a user's personal herbaria if they have multiple.
    Herbarium.connection.select_rows(%(
      SELECT personal_user_id, COUNT(id) FROM herbaria
      WHERE personal_user_id IS NOT NULL GROUP BY personal_user_id
    )).each do |user_id, count|
      next if count == 1
      user = User.find(user_id)
      puts "#{user.login.inspect} has #{count} herbaria!"
      last_herbarium = nil
      Herbarium.where(personal_user_id: user_id).each do |herbarium|
        if last_herbarium
          puts "Merging #{herbarium.name.inspect} with #{last_herbarium.name.inspect}"
          herbarium = herbarium.merge(last_herbarium)
        end
        last_herbarium = herbarium
      end
    end

    # Remove all curators, then make only personal herbaria have a curator.
    puts "Adding users as curator of their personal herbarium"
    Herbarium.connection.execute(%(
      DELETE FROM herbaria_curators
    ))
    personal_herbaria = Herbarium.where.not(personal_user_id: nil)
    Herbarium.connection.execute(%(
      INSERT INTO herbaria_curators (herbarium_id, user_id) VALUES
      #{ personal_herbaria.map { |h| "(#{h.id},#{h.personal_user_id})" }.join(",") }
    ))

    # Remove bogus email addresses from all non-personal herbaria.  In fact
    # remove them all, because we will provide a default email address for
    # personal herbaria.  That way if the user changes their email address,
    # they won't also have to change their herbarium's email address.
    puts "Removing all email addresses"
    Herbarium.connection.execute(%(
      UPDATE herbaria SET email = ""
    ))

    # These are all just garbage -- convert them into notes on herbaria records
    # attached to the user's personal herbarium (creating as necessary).
    [12,44,101,103,108,137,145,149,203,210,212,213,214,299,328,343,363,371,372,
     376,380,420,434,442,454,462,506,508,516,518,533,535,536,537,578,598,607,
     626,635,681,706,729,737,740,743,751,763,764,765,766,767,768,769,770,771,
     772,773,774,775,776,777,778,779,781,782,783,784,785,786,788,789,790,791,
     792,793,794,795,796,797,798,799,800,802,804,808,810,812,813,816,820,821,
     822,823,827,830,831,851,853,854,856,858,860,862,867,884,899,906].each do |id|
      garbage_herbarium = Herbarium.safe_find(id) || next
      comment = garbage_herbarium.name
      puts "Destroying herbarium #{comment.inspect}"
      garbage_herbarium.destroy
      HerbariumRecord.where(herbarium_id: id).each do |herbarium_record|
        if herbarium_record.observations.none?
          puts "Destroying unused herbarium record #{herbarium_record.id}"
          herbarium_record.destroy
          next
        end
        obs = herbarium_record.observations.first
        personal_herbarium = obs.user.personal_herbarium ||
                             obs.user.create_personal_herbarium
        new_notes = "[This record used to be at an herbarium called " \
                    "\"#{comment}\". -admins 20171220]\n\n" \
                    "#{herbarium_record.notes}".
                    gsub(/  +/, " ").gsub(/\a\s+|\s+\z/, "")
        puts "Adding comment #{comment.inspect} to herbarium record ##{herbarium_record.id}"
        herbarium_record.update_attributes(
          herbarium_id: personal_herbarium.id,
          notes: new_notes
        )
      end
    end
  end

  def down
  end
end
