# iNat Fixtures

This file describes the fixtures used to test iNat imports and photos,
and additional fixtures needed for better testing.

## Observations

Unformatted strings comprising the complete result of an [iNat API Get Observation query](https://api.inaturalist.org/v1/docs/#!/Observations/get_observations_id), unless otherwise noted.

All data as of the time of importing. (The corresponding iNat Observation may have changed)

| File | iNat Obs | fotos | location | Other |
| ---- | -------- | ----- | -------- | ----- |
| ceanothus_cordulatus.txt | [219631412](https://www.inaturalist.org/observations/219631412) | 1 | public | **Plant** |
| coprinus.txt | [213450312](https://www.inaturalist.org/observations/213450312) | 1 | **obscured** | |
| evernia_no_photos.txt | [216357655](https://www.inaturalist.org/observations/216357655) | 0 | public | lichen |
| fuligo_septica.txt | [219783802](https://www.inaturalist.org/observations/219783802) | 1 | public | slime mold **Protozoa** |
| gyromitra_ancilis.txt | [216745568](https://www.inaturalist.org/observations/216745568) | 3 | public | **cc-by license**, **many projects** |
| russulaceae.txt | [216675045](https://www.inaturalist.org/observations/216675045) | 2 | public | **all rights reserved**, many projects, Activity |
| somion_unicolor.json |  |  |  | Formatted version of following; facilitates viewing iNat API response key/values |
| somion_unicolor.txt | [202555552](https://www.inaturalist.org/observations/202555552) | 5 | public | Notes, Activity, many IDs, **mirrored from MO**|
| tremella_mesenterica.txt | [213508767](https://www.inaturalist.org/observations/213508767) | 1 | public | |

## TODO

### Needed Observations

- Slime mold
- Fungus with photo that was uploaded to iNat >= 1 day after iNat Obs was created
- Public Domain
https://api.inaturalist.org/v1/observations?identified=true&license=cc0&rank=species&iconic_taxa=Fungi&quality_grade=research&page=1&order=desc&order_by=created_at&only_id=true

- All Rights Reserved
https://api.inaturalist.org/v1/observations?identified=true&licensed=false&rank=species&iconic_taxa=Fungi&quality_grade=research&page=1&order=desc&order_by=created_at&only_id=true
https://www.inaturalist.org/observations/222157696
- No derivatives

Need fixtures with the following fields:

- Activity
- Annotations
- Notes
- Observation Fields
  - provisional name
  - sensu lato
  - sequence
  - Mushroom Observer URL
