This folder holds the ontology files for the Semantic Vernacular System (SVS) 
module.

"svf.owl" is the core ontology for SVS. "envo.owl" is the EnvO ontoloy 
(http://www.environmentontology.org/) imported by "svf.owl". Both of the two 
files will be loaded into the triple store.

"dump/" is a folder that holds the data dump files from the triple store. 

The SVS triple store is located at root@128.128.170.15:/projects/svf/. Fuseki
(http://jena.apache.org/documentation/serving_data/) is used as the SPARQL HTTP 
server, and TDB (http://jena.apache.org/documentation/tdb/) is used as the RDF 
storage. In the directory "/projects/svf/":
* "fuseki/" holds the Fuseki configuration file.
* "svn/ontologies/" holds the ontologies files.
* "system/" holds the bash scripts for operating the triple store.
** "stop.sh": stop the Fuseki server. 
** "load.sh": load ontology files into the TDB triple store.
** "start.sh": start the Fuseki server.
** "dump.sh": dump the database in an N-Quads (.nq) file, and then convert it to
   an .owl file.
* "tdb" holds all the RDF data.
Note: Every time when the "svf.owl" is modified, it needs to be reloaded to the 
triple store. To do this, run the scripts in this order: "stop.sh" -> "load.sh" 
-> "start.sh".