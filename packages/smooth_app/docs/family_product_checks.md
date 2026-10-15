# Family product checks

Add or edit names and completed ages in **My family**, available in onboarding,
search, settings, and product details. Profiles are saved in local preferences.
Each search result shows a colored chip for every member. Open a product and
expand a member in **For your family** to read the reasons.

- Green: no age-related concern found by these checks.
- Red: a label-based reason to limit or avoid the product.
- Grey: insufficient information or a non-food product.

This is nutrition screening. Age alone cannot determine personal medical
suitability, allergies, interactions, or whether a product will cause harm.
Missing sugar, salt/sodium, saturated fat, ingredients, or category prevents a
green result. Known concerns remain red when other fields are missing. Infant
results need age in months and feeding stage; these are never marked green from
age in years alone. Children under 2 also require confirmed added-sugar data.

High-label thresholds are applied per 100 g for foods and per 100 ml for drinks:
total sugars >22.5 g / >11.25 g, salt >1.5 g, saturated fat >5 g / >2.5 g.
These are product-label thresholds, not daily allowances or personalized limits.
Total sugars are not assumed to be added sugars. Sodium in grams is converted
to salt by multiplying by 2.5. Age-specific checks cover honey under 1, added
sugar under 2, and caffeine/alcohol for minors. No disease is inferred from age.
Adult saturated-fat screening is not used for children under 2, whose fat needs
differ. Their results still require complete nutrition and confirmed added-sugar data.

Sources:

- [UK front-of-pack guidance](https://www.gov.uk/government/publications/front-of-pack-nutrition-labelling-guidance)
- [CDC infant and toddler guidance](https://www.cdc.gov/infant-toddler-nutrition/foods-and-drinks/foods-and-drinks-to-avoid-or-limit.html)
- [AAP caffeine guidance](https://www.healthychildren.org/English/healthy-living/nutrition/Pages/the-effects-of-caffeine-on-kids-a-parents-guide.aspx)
- [WHO sodium guidance](https://www.who.int/news-room/fact-sheets/detail/sodium-reduction)

## Optional Groq explanations

The core feature works without an API key or AI. To enable an **Explain simply
with AI** button, copy `config/groq.example.json` to `config/groq.local.json` and
replace `YOUR_GROQ_API_KEY`. The local file is gitignored. From `packages/smooth_app`:

```powershell
flutter run -d emulator-5554 -t lib/entrypoints/android/main_google_play.dart --dart-define-from-file=config/groq.local.json
```

On this Windows workspace, `./scripts/run_android.ps1` loads the local config
automatically and applies the Java socket-path and memory settings used for
the emulator build. Keep the emulator running before launching the script.

Groq only rephrases existing reasons after a button tap; it cannot change colors.
The request contains the age group and screening reasons, not names or exact
ages, plus the selected product's public name, barcode and label nutrients.
Failures leave the local results available. AI explanations are labeled
as AI-generated. No live Groq request is made with the placeholder key.

Groq account availability and usage limits depend on your plan. See
[Groq's API documentation](https://console.groq.com/docs/text-chat).
For a distributed production app, use a backend proxy: build-time keys can be
extracted from a mobile binary even when the local configuration is gitignored.

New feature text is currently in English.

## Matching results and changing the key

Two members in the same age category can legitimately receive the same result.
A high-sugar product may be red for adults and children alike. Matching colours
do not mean matching nutrition values: the cards display the current barcode and
sugar/salt/saturated-fat amounts so the evidence is visible. Quantities are per
100 g or 100 ml as sold, not necessarily the prepared portion of a powder or concentrate.
The older food-preference percentage/N/A header is hidden when family profiles exist.

`groq.local.json` is loaded at build time using `--dart-define-from-file`; editing
it does not change an already-installed app. Rebuild and reinstall after changing
a key or model. The example model is `openai/gpt-oss-20b`. If a model returns 404,
check availability through Groq's `/openai/v1/models` endpoint. Errors for an
unavailable model, rejected key, and rate limits are displayed separately.
