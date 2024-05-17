# iNat Fixtures

This file describes the fixtures used to test iNat imports and photos.

## Observations

Unformatted strings comprising the complete result of an [iNat API Get Observation query](https://api.inaturalist.org/v1/docs/#!/Observations/get_observations_id), unless otherwise noted.
<br>All data as of the time of importing. (The corresponding iNat Observation may have changed)

- `coprinus.txt`: [iNat #213450312](https://www.inaturalist.org/observations/213450312), _Coprinus_, simple, 1 image, location obscured
- `somion_unicolor.json`: Formatted version of following. Convenience file to facilitate seeing the structure and values of an iNat API response.
- `somion_unicolor.txt`: [iNat #202555552](https://www.inaturalist.org/observations/202555552) _Somion unicolor_, complex, multiple photos, multiple IDs, Notes **Exported from MO, so should not be imported from iNat to MO.
- `tremella_mesenterica.txt`: [iNat #213508767](https://www.inaturalist.org/observations/213508767) _Tremella mesenterica_, simple, public, one image

### Needed Observations

- Plant or other non-fungal
- Slime mold
- Fungus with photo that was uploaded to iNat >= 1 dat after iNat Obs was created
- Multiple photos, not mirrored from MO

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

## Images

Hash comprising (describing) one of the `observation_photos` in the result of an [iNat API Get Observation query](https://api.inaturalist.org/v1/docs/#!/Observations/get_observations_id).
<br>The number in the filename is the `observation_photo [:id]`, **not** the `photo[:id]`

- `inat_obs_photo_351481052.txt` the only photo from the Observation `tremella_mesenterica.txt`.

### Needed photos

- with different licenses
