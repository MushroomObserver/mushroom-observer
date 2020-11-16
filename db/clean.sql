update api_keys set `key` = 'cahja4s81achfojjlqzgkt16qgkl2hira';

update donations set email = 'webmaster@mushroomobserver.org';
update donations set who = 'anonymous' where anonymous = true;

update herbaria set email = 'webmaster@mushroomobserver.org';

update image_votes set user_id = 0 where anonymous = true;

update images set original_name = 'xxx';

update observations set `lat` = null, `long` = null where `gps_hidden` = true;

# delete from interests;

delete from t using location_descriptions_admins as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_descriptions_authors as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_descriptions_editors as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_descriptions_readers as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_descriptions_versions as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_descriptions_writers as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from location_descriptions where public = false;

delete from t using name_descriptions_admins as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_descriptions_authors as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_descriptions_editors as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_descriptions_readers as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_descriptions_versions as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_descriptions_writers as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from name_descriptions where public = false;

# delete from notifications;

delete from query_records;

delete from queued_email_integers;
delete from queued_email_notes;
delete from queued_email_strings;
delete from queued_emails;

update users set email = 'webmaster@mushroomobserver.org';
update users set password = 'ae98587c6f1599fbdcc800e66db6874a8fa0e713';

update votes
 inner join users on users.id = votes.user_id
 set votes.user_id = 0
 where users.votes_anonymous = 'yes'
    or (users.votes_anonymous = 'old' and votes.created_at < 20100401);

commit;
