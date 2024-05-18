# iNat Fixtures

This file describes the fixtures used to test iNat imports and photos.

## Observations

Unformatted strings comprising the complete result of an [iNat API Get Observation query](https://api.inaturalist.org/v1/docs/#!/Observations/get_observations_id), unless otherwise noted.
<br>All data as of the time of importing. (The corresponding iNat Observation may have changed)

| File | iNat Obs | fotos | location | Other |
| ---- | -------- | ----- | -------- | ----- |
| evernia_no_photos.txt | [216357655](https://www.inaturalist.org/observations/216357655) | 0 | public | |
| tremella_mesenterica.txt | [213508767](https://www.inaturalist.org/observations/213508767) | 1 | public | |
| coprinus.txt | [213450312](https://www.inaturalist.org/observations/213450312) | 1 | obscured | |
| somion_unicolor.json |  |  |  | Formatted version of following; facilitates viewing iNat API response key/values |
| somion_unicolor.txt | [202555552](https://www.inaturalist.org/observations/202555552) | 5 | public | Nates, Activity, multiple IDs, **mirrored from MO**|

### Needed Observations

- iNat Obs without images (for a simple InatImportsControllerTest)
- Plant or other non-fungal
- Slime mold
- Fungus with photo that was uploaded to iNat >= 1 dat after iNat Obs was created
- Multiple photos, not mirrored from MO
- Photo with license that's not the MO default

Need fixtures with the following fields:

- Activity
- Annotations
- Notes
- Projects
- Observation Fields
  - provisional name
  - sensu lato
  - sequence
  - Mushroom Observer URL
