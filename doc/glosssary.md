# MO Glossary of Mycological Terms

The Glossary is a community-maintained list of mycological terms.

<details>
<summary>Background</summary>

The MO Glossary began in 2015 in collaboration with the Rhode Island School of Design;
students from Jean Blackburn’s Scientific Illustration class created
high-quality Creative Commons licensed scientific illustrations
of fungal anatomy terms.

The Glossary has since been improved to:

- support multiple images including both scientific illustrations and example photographs.
- include a search feature; and
- support internal links to terms as part of any Mushroom Observer markup.

One feature that needs discussion is how best to handle translations
of terms and definitions.
Discussion is welcome on the
[Mushroom Observer Google Group]([mo-general@googlegroups.com](https://groups.google.com/g/mo-general)).
You are also welcome to leave comments on the
[unofficial Mushroom Observer Facebook page](https://www.facebook.com/groups/mushroomobserver).
(But note that the Facebook page is not monitored by the MO Development Team.)
</details>

## Guidelines

Please follow these Guidelines when creating or editing Glossary Terms.

### Who can contribute?

The glossary entries are created and edited by members of the MO community.
(No individual member owns any entry.) Everyone is welcome to contribute.

### Terms to Include

- Include mycology-specific terms,
   especially those relating to
   the identification, taxonomy, nomenclature, and ecology of macrofungi.
   Avoid terms lacking a mycology-specific definition, other than
   Latin technical terms commonly used in mycology.
   <details>
   <summary>Examples</summary>

   good: `aborts`. (Mycological definition differs from the ordinary English meaning.)

   good: `abaxial`. (Latin technical term commonly used in mycology)

   good: `character`.

   good: `club fungi`

   bad: `abraded` (An  English word lacking a mycology-specific definition.)

   bad: `Cell`

   bad: `Cell Biology`

   bad: `Chemical Species`

   bad: `Chirality`

   bad: `Climate Change`

   bad: `rhombus`

   bad: `Science`

   bad: `Scientific Methodology`

   </details>

- Terms that are straightforward modifications or combinations of other terms
   should not have their own definitions,
   but are welcome to be given entries with illustration(s).

   <details>
   <summary>Examples</summary>

   bad:  `Lamellae Edge With Gelatinous, Separable Layer`

   bad:  `Oblong With Median Constriction`

   bad:  `Round To Angular Pores`

   bad:  `Transition Between Hymeniderm And Epithelium`

   good: `Lugol's Solution`

   good: `adnate`
   (plus exampble showing adnate gills)
   </details>

- Avoid terms that are scientific names of taxa.
   Instead, add a Description to the taxon Name.

   <details>
   <summary>Examples</summary>

   bad:  `Agaricales`

   bad:  `Basidiomycota`

   bad: `Eukarya`

   good: `bolete`
   </details>

- Include terms that are actually used in mycology -- don't make stuff up.

## Titles

- Titles (the "Name" field) should be lowercase, except for proper nouns or
   other terms that are capitalized in ordinary use.
   <details>
   <summary>Examples</summary>
   <div style="background-color: rgb(80, 80, 80);">

   bad:  `Bolete`

   good: `bolete`

   good: `RPB2`
   </div>
   </details>

- Prefer shorter titles.
   <details>
   <summary>Explanation</summary>
  Improves readibility, functionality, and performance, and
  is kinder to users with small screens.
   </details>

## Descriptions

Each term must have a Description and/or Illustration(s).

### Definitions

A Description may include a definition.

- Make it a definition, rather than history, background, purpose,
  stuff you found out when researching the topic, etc.

   <details>
   <summary>Examples</summary>
   <div style="background-color: rgb(80, 80, 80);">

   ```text
      bad:  Casing Layer
            1. When mushrooms are cultivated indoors or outdoors,
            they are often developed using a layered system involving a variety of
            potential materials. The casing layer is the top-most layer which
            covers all of the layers. It can be composed of moist materials such
            as peat, gypsum, vermiculite, and/or several other optional materials.
            This moisture-promoting layer dramatically enhances mushroom formation
            as well as more abundant mushroom growth in most cultivated species.
            Some mushroom species require a casing layer in order to fruit,
            or to fruit with any significance.

      good: Casing Layer
            The top layer of material used in indoor mushroom cultivation.
   ```

   </div>
   </details>

- Keep definitions concise.

   <details>
   <summary>Explanation</summary>
  Improves readibility, functionality, and performance, and
  is kinder to users with small screens.
   </details>

- Match the part of speech of the term, or use a complete sentence.

   <details>
   <summary>Examples</summary>
  A definition for a noun might begin with "A sterile cell that..."
  One for an adjective might begin with "Bearing cystidia that..."
   </details>
- Number definitions if (and only if) multiple definitions are included.

- Don't repeat definitions. Instead link to an existing Glossary Term
  that includes that definition.
  <details>
  <summary>Example</summary>

  bad:

  ```text
        Spiciform:

           1. Exhibiting spike-shaped projections.

        Spicules:

        (Spiculate, Spiculose, Spiculum)

           2. Exhibiting many small spines.

           3. Small spikes.
  ```

  good:

  ```text
        spiciform:

           Having _spicules_.

        spicules:

           (spiculate, spiculose, spiculum, spiciform)

           Small spikes or spines.
  ```

  </details>

## Illustrations

- Preferably include an illustration.
- Omit "illustrations" that are simply rendered text.
  <details>
  <summary>Example</summary>

   ![Alt text](glossary_text_only_illustration.png)

  </details>

- Use only illustrations that:
   you created,
   are in the public domain, or
   are licensed.
   Comply with the license terms if you use licensed illustrations.
- Limit the number and size of illustrations
   to those that are necessary to define the term.

## Sample Terms

Examples following these Guidelines.

<details>
  <summary>Example with single definition</summary>

  ![Alt text](glossary_sample_entry_glandular_dots_rendered.png)

</details>

<details>
  <summary>Example with multiple definitions, showing both markup and result</summary>

### Textile markup

  ![Alt text](glossary_sample_entry_bolete_textile.png)

### Rendered result

![Alt text](glossary_sample_entry_bolete_rendered.png)

</details>

## Internal Links to the Glossary

- Use all lower-case words whose spelling exactly matching the term,
  surrounded by underscores.

>`_bolete_` (renders as ***bolete***)

- To render the link in different cases use this format:

>`_term Bolete_` (renders as ***Bolete***)

## Glossary Searches

The Glossary can be searched via the search bar at the top of the screen.
Searches do not require an exact match. They return a list of all
Glossary Terms matching the search criteria.
