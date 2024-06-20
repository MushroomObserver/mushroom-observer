# iNat Examples

This file

- Describes files used to stub requests to the iNat API and otherwise substitute for iNat API responses;
- Lists additional examples needed for better testing.

## Observations

Strings comprising the body of a response to an [iNat API Get Observation query](https://api.inaturalist.org/v1/docs/#!/Observations/get_observations_id),
unless otherwise noted.

All data as of the time of importing. (The corresponding iNat Observation may have changed)

| File | iNat Obs | fotos | location | Other |
| ---- | -------- | ----- | -------- | ----- |
| ceanothus_cordulatus.txt | [219631412](https://www.inaturalist.org/observations/219631412) | 1 | public | **Plant** |
| coprinus.txt | [213450312](https://www.inaturalist.org/observations/213450312) | 1 | **obscured** | |
| evernia_no_photos.txt | [216357655](https://www.inaturalist.org/observations/216357655) | 0 | public | lichen, no fields|
| fuligo_septica.txt | [219783802](https://www.inaturalist.org/observations/219783802) | 1 | public | slime mold **Protozoa** |
| gyromitra_ancilis.txt | [216745568](https://www.inaturalist.org/observations/216745568) | 3 | public | **cc-by license**, **many projects** |
| inocybe.txt | [222904190](https://www.inaturalist.org/observations/222904190) | 5 | public | cc-by-nc, **2 tags** |
| lyocperdon.txt | [24970904](https://www.inaturalist.org/observations/24970904) | 2 | public | cc-by-nc, projects, Activity, >1 field including, **DNA** |
| russulaceae.txt | [216675045](https://www.inaturalist.org/observations/216675045) | 2 | public | **all rights reserved**, many projects, Activity |
| somion_unicolor.json |  |  |  | Formatted version of following; facilitates viewing iNat API response key/values |
| somion_unicolor.txt | [202555552](https://www.inaturalist.org/observations/202555552) | 5 | public | Notes, Activity, >1 ID, 1 field (Mushroom Observer URL), **mirrored from MO** |
| trametes.txt | [220370929](https://www.inaturalist.org/observations/220370929) | 2 | public | D. Miller observation with different collector; Notes; **Observation Fields: Collector** |
| tremella_mesenterica.txt | [213508767](https://www.inaturalist.org/observations/213508767) | 1 | public | |

## TODO

### Needed Observation Examples

iNat fungal Obss with these fields/licenses

- Notes
- Observation Fields
  - sequence (need a variety of these; there are many ways to add sequences to iNat Obss)
  - provisional name
  - sensu lato
  - various dna fields (DNA Barcode ITS, Collector, Collection Number)
- Annotations
- Activity
- Public Domain
https://api.inaturalist.org/v1/observations?identified=true&license=cc0&rank=species&iconic_taxa=Fungi&quality_grade=research&page=1&order=desc&order_by=created_at&only_id=true
- nonderiv license
- Fungus with photo that was uploaded to iNat >= 1 day after iNat Obs was created
- Obs with narrower Photo license than overall Obs License
