use mo_development;

update api_keys set `key` = SUBSTR(SHA2(CONCAT(id, UUID()), 256), 1, 32);

update donations set email = 'webmaster@mushroomobserver.org';
update donations set who = 'anonymous' where anonymous = true;

update herbaria set email = 'webmaster@mushroomobserver.org';

update image_votes set user_id = 0 where anonymous = true;

update images set original_name = 'xxx';

update observations set `lat` = null, `lng` = null where `gps_hidden` = true;

# delete from interests;

delete from t using location_description_admins as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_description_authors as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_description_editors as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_description_readers as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_description_versions as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from t using location_description_writers as t
 inner join location_descriptions as ld on ld.id = t.location_description_id
 where ld.public = false;

delete from location_descriptions where public = false;

delete from t using name_description_admins as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_description_authors as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_description_editors as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_description_readers as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_description_versions as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from t using name_description_writers as t
 inner join name_descriptions as ld on ld.id = t.name_description_id
 where ld.public = false;

delete from name_descriptions where public = false;

# delete from name_trackers;

delete from query_records;

update users set email = 'webmaster@mushroomobserver.org';
# Set all passwords to just "password".
update users set password = 'ae98587c6f1599fbdcc800e66db6874a8fa0e713';
# `auth_code` is the remember-me secret and binds the server session, so
# a snapshot carrying it can mint a login for any account.
update users
 set auth_code = substr(sha2(concat(id, uuid()), 256), 1, 40);

update votes
 inner join users on users.id = votes.user_id
 set votes.user_id = 0
 where users.votes_anonymous > 1;

# Both columns are newer than the oldest snapshots the image server
# retains, so they come last: on a dump predating them, the
# unknown-column error aborts the script with everything above applied.

# Blocks login, leaving those accounts unusable in a copy.
update users set password_reset_required = false;
# An iNaturalist OAuth code or JWT for the importing user's iNat account.
update inat_imports set token = null;

commit;
