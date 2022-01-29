Mushroom Observer API
=====================

Change Log
----------

v1 -- First version 2016.
v2 -- Latest version 2020.

The endpoint is now "api2" instead of "api".  The old endpoint will be phased
out some time in 2021.  The default format is now JSON not XML, since JSON is
significantly faster.  And a few result structures have been tweaked slightly:

api_keys -- field names were wrong (created_at, last_used, num_uses)

herbarium_records -- field names were wrong (initial_determination,
accession_number)

images -- moved observation_ids to high-detail response

observations -- full consensus, location and owner details moved to high detail
response, now only consensus_id, consensus_name, location_id, location_name and
owner_id are found in low detail response; votes moved up to top level of the
structure for high detail response (used to be buried within namings)

projects -- removed admin and member ids

species_lists -- removed project_ids, full location details only available in
high detail response now

collection_numbers, comments, external_links, herbarium_records -- only
includes observation ids now not full details

CSV files
---------

Note that we update a set of CSV files nightly which are straight dumps of the
database.  If you are looking for large quantities of data, e.g. for data
anaylsis or image recognition, plase look at these files first to see if they
have the information you need.  That will save our server a considerable amount
of unnecessary traffic, and probably save you a lot of work!

* https://mushroomobserver.org/observations.csv
* https://mushroomobserver.org/images_observations.csv
* https://mushroomobserver.org/names.csv
* https://mushroomobserver.org/locations.csv

Overview
--------

Mushroom Observer supports a simple API based on sending GET, POST, PATCH and
DELETE requests to URLs of the form:
```
https://mushroomobserver.org/api2/<database_table>
```
GET requests are read-only and do not require authentication.  POST (create),
PATCH (update) and DELETE (destroy) requests require authentication via an API
key (see below).

Responses can be requested in either JSON (default) or XML. You can either
set the appropriate HTTP request header, or you can request it explicitly with
a parameter (see below).

Rate and Load Restrictions
--------------------------

We limit anonymous traffic to MO, including API traffic, by restricting the
rate of requests to 20 per minute (1 request every 5 seconds on average), and
less than 50% of the resoures of a single server instance.  A good rule of
thumb would be to read the "run_time" from the response, and make sure you wait
at least 5 seconds or the last run_time before making a new request.  If you
get locked out, please contact us and we can discuss your needs and perhaps
better ways of achieving them.

GET Requests
------------

All GET queries accept a bunch of parameters allowing you to restrict the
results to a specified subset.  For example, you can filter observations by
name, location, date, user, confidence, presence of images, comment text, etc.
Combinations are of course welcome.

In addition to these filter parameters a few special pseudoparameters are
accepted:

* help=1 -- Resturn a list of accepted parameters.
* detail=none -- Return only record ids (default).
* detail=low -- Return some basic data with each record.
* detail=high -- Return a great deal of data with each record.
* format=json -- Return JSON response (default).
* format=xml -- Return XML response.

Note that the result will be paginated for detailed responses.  High detail
responses in particular are intended for very small data sets.  (High detail
responses generally include 100 results per page, low detail 1000 per page).

It is easy to play with this aspect of the API in a browser.  Try the following
queries, for example:

* GET <https://mushroomobserver.org/api2/observations?children_of=Tulostoma>
* GET <https://mushroomobserver.org/api2/observations?locations=Delaware&date=6>
* GET <https://mushroomobserver.org/api2/observations?help=1>

These return, respectively, (1) ids of all observations of the genus Tulostoma,
(2) ids of all observations from Delaware posted in June (any year), and (3) a
list of accepted query parameters.

POST Requests
-------------

Most tables accept POST requests for creating new records.  Include data for
the new record in parameters.  Example:

* POST <https://mushroomobserver.org/api2/observations?api_key=xxx&name=Agaricus&location=Pasadena,+California,+USA&date=2016-08-06&notes=growing+in+lawn>

The response will include the id of the new record.

Attach the image as POST data or URL.  See script/test_api for an example of how
to attach an image in the POST data.

PATCH Requests
--------------

Structure your PATCH query the same as for GET requests, but also include
"set_xxx" parameters to tell MO how to modify the matching records.  For
example, this would be a way to change the location of a set of your
observations:

* PATCH <https://mushroomobserver.org/api2/observations?api_key=xxx&user=jason&id=12300-12400&set_location=Pasadena,+California,+USA>

DELETE Requests
---------------

Structure the query the same as for GET requests.  MO will destroy all matching
records (that you have permission to destroy).  For example, this should delete
all your observations from a given location:

* DELETE <https://mushroomobserver.org/api2/observations?api_key=xxx&user=jason&locations=Madison+Heights,+Pasadena,+California,+USA>

API Keys
-------------

Authorization is currently done using an API key.  Just include your API key in
any POST, PATCH and DELETE requests.  An API key belongs uniquely to a single
user, so MO will know who you are.

The easiest way for an individual user to obtain an API key is to create one
directly via the website:

* <https://mushroomobserver.org/account/api_keys>

For convenience, apps may also create a key on behalf of a user using a POST
request:

* POST <https://mushroomobserver.org/api2/api_keys?api_key=xxx&user=xxx>

In this latter case, the app creator must first create an API key by hand for
that app.  This is the key that will be used in the request above to create a
new API key for another user.  The user will then receive an email asking them
to confirm that it's okay for your app to post observations and images and such
in their name.  The app will then use the user's new API key for all subsequent
POST requests.  The app will be responsible for remembering and keeping secure
each user's API key.

Apparently, it should also be possible for an app to create an account for a
new user, too.  I don't remember writing this, but it apparently has extensive
unit tests to guarantee that it works correctly(!)  Presumably the new user
will have to verify their email address like usual before the app can create an
API key for them and post observations.

All of this is still very unsecure.  If anyone gets hold of a user's API key
they can readily POST things in their name.  Anyone interested in hooking us up
with a more sophisticated authentication process is welcome to contribute.
We'd be happy to help.

Database Tables
---------------

Most of the important database tables have entry points:

* api_keys (POST only)
* comments
* external_links
* external_sites (GET only)
* herbaria (GET only)
* images
* locations (not DELETE)
* names (not DELETE)
* observations
* projects (not DELETE)
* sequences
* species_lists
* users (not DELETE)

Use the special "help=1" parameter to request a set of parameters supported for
each table.  Detailed documentation doesn't exist; we're relying on things
being simplistic enough to be more or less self-explanatory.  Note that it is
safe to mess around with strange parameters and see what they do.  Note that
XML responses include a copy of the SQL query used.  This can be a very
effective way of discovering exactly how unfamiliar parameters work.  Here's
the SQL query from one of the examples above:
```sql
SELECT DISTINCT observations.id
FROM `observations`
WHERE MONTH(observations.when) >= 6 AND MONTH(observations.when) <= 6
AND (observations.location_id IN (694,...,14040) OR observations.where LIKE '%Delaware%')
ORDER BY observations.id ASC
```
See also the database diagram here:

* <https://github.com/MushroomObserver/mushroom-observer/blob/master/DATA_STRUCTURE.gif>

and the database schema here:

* <https://github.com/MushroomObserver/mushroom-observer/blob/master/db/schema.rb>
