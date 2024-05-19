# iNat Fixtures

This file describes the fixtures used to test iNat imports and photos,
and additional fixtures needed for better testing.

## Observations

Unformatted strings comprising the complete result of an [iNat API Get Observation query](https://api.inaturalist.org/v1/docs/#!/Observations/get_observations_id), unless otherwise noted.

All data as of the time of importing. (The corresponding iNat Observation may have changed)

| File | iNat Obs | fotos | location | Other |
| ---- | -------- | ----- | -------- | ----- |
| evernia_no_photos.txt | [216357655](https://www.inaturalist.org/observations/216357655) | 0 | public | |
| tremella_mesenterica.txt | [213508767](https://www.inaturalist.org/observations/213508767) | 1 | public | |
| coprinus.txt | [213450312](https://www.inaturalist.org/observations/213450312) | 1 | obscured | |
| somion_unicolor.json |  |  |  | Formatted version of following; facilitates viewing iNat API response key/values |
| somion_unicolor.txt | [202555552](https://www.inaturalist.org/observations/202555552) | 5 | public | Nates, Activity, multiple IDs, **mirrored from MO**|

## TODO

### Needed Observations

- Plant or other non-fungal
- Slime mold
- Fungus with photo that was uploaded to iNat >= 1 day after iNat Obs was created
- Multiple photos, not mirrored from MO
- Photo with license that's not the MO default
  - [216745568](https://www.inaturalist.org/observations/216745568), cc-by license, multiple photos, multiple projects
  - [216675045](https://www.inaturalist.org/observations/216675045), all rights reserved, multiple images, multiple projects, Activity
  - Public Domain

Need fixtures with the following fields:

- Activity
- Annotations
  - [216853118](https://www.inaturalist.org/observations/216853118), one Annotation, one photo
- Notes
- Projects
- Observation Fields
  - provisional name
  - sensu lato
  - sequence
  - Mushroom Observer URL
