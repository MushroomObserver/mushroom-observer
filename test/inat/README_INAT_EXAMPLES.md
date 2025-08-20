# iNat Examples

This file

- Describes files used to stub requests to the iNat API and otherwise substitute for iNat API responses;
- Lists additional examples needed for better testing.

## Observations

Strings comprising the body of a response to an [iNat API Observation Search](https://api.inaturalist.org/v1/docs/#!/Observations/get_observations),
unless otherwise noted.
The files do not contain conidential data, except as otherwise noted.
The file is in json format. It includes the complete search result, which includes `results`, which include the `observation`(s).

All data as of the time of importing. (The corresponding iNat Observation may have changed)

<!-- markdownlint-disable MD013 -->
| File | iNat Obs | fotos | location | Other |
| ---- | -------- | ----- | -------- | ----- |
| amanita_flavorubens | [231104466](https://www.inaturalist.org/observations/231104466) | **0** | public | Casual |
| arrhenia_sp_NY02 | [184219885](https://www.inaturalist.org/observations/184219885) | 1 | public | `johnplischke` mo-style Provisional Species Name, DNA, NEMF, notes, 2? identifications with same id, comments, everyone has MO account, many obs fields, including "Voucher Number(s)", "Voucher Specimen Taken" |
| calostoma_lutescens | [195434438](https://www.inaturalist.org/observations/195434438) | **0** | user `mycoprimuspublic` | barebones. NO: photo, added ids, or observation_fields |
| ceanothus_cordulatus | [219631412](https://www.inaturalist.org/observations/219631412) | 1 | public | **Plant** |
| coprinus | [213450312](https://www.inaturalist.org/observations/213450312) | 1 | **obscured** | Needs ID |
| distantes | [215996396](https://www.inaturalist.org/observations/215996396) | 1 | `jdcohenesq` **obscured, includes confidential gps** | Needs ID, jdc Obs, taxon[:name]: "Distantes" rank:"section", rank_level:13 |
| donadinia_PNW01 | [212320801](https://www.inaturalist.org/observations/212320801) | 1 | public | `danmorton` **non-mo-style Provisional Species Name (PNW)**, **DNA sequence** |
| evernia | [216357655](https://www.inaturalist.org/observations/216357655) | 1 | public | user `jgerend` Casual, lichen, no fields, place: Troutdale, 1 Project |
| fuligo_septica | [219783802](https://www.inaturalist.org/observations/219783802) | 1 | public | slime mold **Protozoa** Richmond, CA |
| gyromitra_ancilis | [216745568](https://www.inaturalist.org/observations/216745568) | 3 | public | **cc-by license**, **many projects**, **suggested Inactive Taxon** US 20, Linn Co.|
| hygrocybe_sp_conica-CA06_ncbi_style | [197869712](https://www.inaturalist.org/observations/197869712) | 2 | public | note: I removed MO Obs field |
| import_all |  |  | | all fungal obss (total of 5) of iNat user `devin189`, 2 per page (this user had few fungal observations) |
| inocybe | [222904190](https://www.inaturalist.org/observations/222904190) | 5 | public | cc-by-nc, **2 tags** |
| i_obliquus_f_sterilis | [232919689](https://www.inaturalist.org/observations/232919689) | 1 | public | `taigamushrooms` cc-by-nc, **infraspecific name** |
| lentinellus_ursinus | [220796026](https://inaturalist.org/observations/220796026) | 2 | obscured | **ID matches many MO Name fixtures** |
| listed_ids | [231104466](https://www.inaturalist.org/observations/231104466) [195434438](https://www.inaturalist.org/observations/195434438) | na | na | response to request for 2 obs by number (amanita_flavorubens, evernia) |
| lycoperdon | [24970904](https://www.inaturalist.org/observations/24970904) | 2 | public | user `dannymi` cc-by-nc, projects, Had 2 photos, 6 identifications of 3 taxa, a different taxon, 9 obs fields, including "DNA Barcode ITS", "Collection number", "Collector", place: E. side of Metolius River, Sisters Ranger District, Deschutes National Forest, Jefferson County, Oregon, US |
| no_location | [12826267](https://www.inaturalist.org/observations/12826267) | 1 | public | no location, place: Barlow Ranger District, Wasco Co., Oregon, USA |
| russula_subabietis| [307145241](https://www.inaturalist.org/observations/307145241) | 2 | public | **Observation Fields: `Collector's name`, `Voucher Number(s)`, `Voucher Specimen Taken` ** 2025 Summer Continental Mycoblitz, Mike Beug |
| russulaceae | [216675045](https://www.inaturalist.org/observations/216675045) | 2 | public | **all rights reserved**, many projects, Activity; place: Point Defiance Park, Tacoma, WA, US |
| somion_unicolor.json |  |  |  | Formatted version of following; facilitates viewing iNat API response key/values test/inat/somion_unicolor.json |
| somion_unicolor | [**202555552**](https://www.inaturalist.org/observations/202555552) | 5 | public |  `jdcohenesq` Research Grade, Notes, Activity, >1 ID, 1 field (Mushroom Observer URL), **mirrored from MO** |
| trametes | [220370929](https://www.inaturalist.org/observations/220370929) | 2 | public | user `dannymi` different collector; Notes; **Observation Fields: Collector**, place: 25th Ave NE, Seattle, WA, US, with huge error |
| tremella_mesenterica | [213508767](https://www.inaturalist.org/observations/213508767) | 1 | public | place: Lewisville, TX 75057, USA |
| xeromphalina_campanella_complex | [215969102](https://www.inaturalist.org/observations/215969102) | 2 | public | `jdcohenesq` **Complex** |
| zero_results | n.a. | | n.a. | response with total_results: 0, to expose and prevent reversion of bug |
<!-- markdownlint-enable MD013 -->

### Potential Additional Observation Examples

iNat fungal Obss with these fields/licenses

- Observation Fields
  - sequence (need a variety of these;
    there are many ways to add sequences to iNat Obss)
  - sensu lato
  - various dna fields (DNA Barcode ITS, Collector, Collection Number)
- Activity
- Annotations
- Public Domain
  <https://api.inaturalist.org/v1/observations?identified=true&license=cc0&rank=species&iconic_taxa=Fungi&quality_grade=research&page=1&order=desc&order_by=created_at&only_id=true>
- nonderiv license
- Fungus with photo that was uploaded to iNat >= 1 day
  after iNat Obs was created
- Obs with narrower Photo license than overall Obs License.
