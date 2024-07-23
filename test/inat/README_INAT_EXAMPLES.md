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
| arrhenia_sp_NYO2.txt | [184219885](https://www.inaturalist.org/observations/184219885) | 1 | public | **mo-style Provisional Species Name**, **DNA** |
| ceanothus_cordulatus.txt | [219631412](https://www.inaturalist.org/observations/219631412) | 1 | public | **Plant** |
| coprinus.txt | [213450312](https://www.inaturalist.org/observations/213450312) | 1 | **obscured** | Needs ID |
| donadina_PNW01.txt | [212320801](https://www.inaturalist.org/observations/212320801) | 1 | public | **non-mo-style Provisional Species Name**, **DNA** |
| evernia_no_photos.txt | [216357655](https://www.inaturalist.org/observations/216357655) | 0 | public | Casual, lichen, no fields, place: Troutdale |
| fuligo_septica.txt | [219783802](https://www.inaturalist.org/observations/219783802) | 1 | public | slime mold **Protozoa** Richmond, CA |
| gyromitra_ancilis.txt | [216745568](https://www.inaturalist.org/observations/216745568) | 3 | public | **cc-by license**, **many projects**, US 20, Linn Co.|
| inocybe.txt | [222904190](https://www.inaturalist.org/observations/222904190) | 5 | public | cc-by-nc, **2 tags** |
| lentinellus_ursinus.txt | [220796026](https://inaturalist.org/observations/220796026) | 2 | obscured | **ID matches many MO names** |
| listed_ids.txt | na | na | na | response to request for 2 obs by number (evernia_no_photos, fuligo_septica) |
| lycoperdon.txt | [24970904](https://www.inaturalist.org/observations/24970904) | 2 | public | cc-by-nc, projects, Activity, many fields including **DNA**, place: E. side of Metolius River, Sisters Ranger District, Deschutes National Forest, Jefferson County, Oregon, US |
| russulaceae.txt | [216675045](https://www.inaturalist.org/observations/216675045) | 2 | public | **all rights reserved**, many projects, Activity; place: Point Defiance Park, Tacoma, WA, US |
| somion_unicolor.json |  |  |  | Formatted version of following; facilitates viewing iNat API response key/values test/inat/somion_unicolor.json |
| somion_unicolor.txt | [202555552](https://www.inaturalist.org/observations/202555552) | 5 | public | Research Grade, Notes, Activity, >1 ID, 1 field (Mushroom Observer URL), **mirrored from MO** |
| trametes.txt | [220370929](https://www.inaturalist.org/observations/220370929) | 2 | public | D. Miller observation with different collector; Notes; **Observation Fields: Collector**, place: 25th Ave NE, Seattle, WA, US, with huge error |
| tremella_mesenterica.txt | [213508767](https://www.inaturalist.org/observations/213508767) | 1 | public | place: Lewisville, TX 75057, USA |

## TODO

### Needed Observation Examples

iNat fungal Obss with these fields/licenses

- Notes
- Observation Fields
  - sequence (need a variety of these; there are many ways to add sequences to iNat Obss)
  - sensu lato
  - various dna fields (DNA Barcode ITS, Collector, Collection Number)
- Activity
- Annotations
- Public Domain
<https://api.inaturalist.org/v1/observations?identified=true&license=cc0&rank=species&iconic_taxa=Fungi&quality_grade=research&page=1&order=desc&order_by=created_at&only_id=true>
- nonderiv license
- Fungus with photo that was uploaded to iNat >= 1 day after iNat Obs was created
- Obs with narrower Photo license than overall Obs License.
