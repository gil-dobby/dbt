# phoenix_dbt

תרגול לקראת הטמעת dbt Cloud בפניקס. dbt-core 1.12.3 / dbt-snowflake 1.12.0,
מול חשבון Snowflake `othxefq-ma88174`.

---

## שכבות ה-ELT

`E` ו-`L` קורים מחוץ ל-dbt — משהו (Fivetran, COPY INTO) מביא נתונים גולמיים
ל-`RAW`. dbt מתחיל רק מה-`T`, וקורא מ-`RAW` בלבד. **dbt לעולם לא כותב ל-RAW.**

```
RAW.CRM                     ← שכבת ה-EL. dbt קורא, לא כותב.
   │
   │  source('crm', ...)
   ▼
staging/crm/                ← 1:1 מול טבלת מקור. rename, cast, ניקוי.
   stg_crm__customers          אסור: joins, aggregations, לוגיקה עסקית.
   stg_crm__policies           materialized: view
   stg_crm__claims
   │
   │  ref(...)
   ▼
intermediate/insurance/     ← כאן מותרים joins לראשונה. שכבת עזר.
   int_claims_enriched         materialized: ephemeral — לא נוצר אובייקט
   │
   │  ref(...)
   ▼
marts/insurance/            ← השכבה העסקית. זו שה-BI נוגע בה.
   dim_customers               materialized: table
   dim_policies
   fct_claims
```

**כלל הזהב:** `ref()` ו-`source()` בלבד. אף שם טבלה מלא בשום `.sql`. זה מה
שבונה את ה-DAG ומאפשר ל-dbt לדעת את סדר ההרצה.

---

## מבנה הקבצים

```
phoenix_dbt/
├── dbt_project.yml                      ברירות מחדל לפי שכבה
├── macros/dbt_created.sql
└── models/
    ├── staging/crm/
    │   ├── _crm__sources.yml            הצהרת המקור
    │   ├── _stg_crm__models.yml         תיעוד + tests
    │   └── stg_crm__{customers,policies,claims}.sql
    ├── intermediate/insurance/
    │   ├── _int_insurance__models.yml
    │   └── int_claims_enriched.sql
    └── marts/insurance/
        ├── _insurance__models.yml
        └── {dim_customers,dim_policies,fct_claims}.sql

../snowflake/                            מחוץ לפרויקט dbt — זו שכבת ה-EL
├── 00_seed_raw_crm.sql                  יוצר RAW.CRM + נתוני דמה
└── 01_verify.sql                        שאילתות אימות
```

קבצי ה-yml מתחילים ב-`_` כדי שיצופו לראש התיקייה. `__` בשם המודל מפריד בין
המקור לטבלה: `stg_<מקור>__<טבלה>`.

---

## המוסכמות שבחרנו, ולמה

### materialization לפי שכבה

מוגדר פעם אחת ב-`dbt_project.yml`, לא בכל מודל:

| שכבה | materialized | למה |
|---|---|---|
| staging | `view` | אין ערך באחסון כפול של המקור. תמיד טרי. |
| intermediate | `ephemeral` | שכבת עזר. לא צריכה להתקיים, ואסור ל-BI לצרוך אותה. |
| marts | `table` | ה-BI קורא מזה הרבה. עדיף לשלם פעם אחת בבנייה. |

מודל בודד יכול לדרוס עם `{{ config(...) }}` בקובץ ה-sql שלו.

### `dbt_created`

מאקרו ב-`macros/dbt_created.sql`, מופיע בכל אחד משבעת המודלים:

```sql
{{ dbt_created() }} as dbt_created
```

הוא מבוסס על `run_started_at` ולא על `current_timestamp()` — **בכוונה**.
`current_timestamp()` מוערך בכל מודל בנפרד, ואז לשכבות שונות באותה הרצה יש
חותמות שונות ואי אפשר לענות על "מאיזו הרצה השורה הזו". עם `run_started_at`
כל ה-DAG נושא ערך זהה. אימות: שאילתה 3 ב-`01_verify.sql` — 72 שורות, ערך
distinct אחד.

בשכבת ה-view החותמת נצרבת לתוך ה-DDL של ה-view ברגע היצירה, אז היא לא זזה
בכל שאילתה.

### tests

42 סה"כ. `unique` + `not_null` על כל מפתח ראשי, `relationships` בין השכבות,
`accepted_values` על הסטטוסים, `not_null` על `dbt_created`.

ה-`accepted_values` מסומנים ב-`TODO` — הערכים שם הם ניחוש, וצריך ליישר אותם
מול מה שבאמת מגיע ב-RAW.

---

## פקודות

```bash
cd phoenix_dbt && source ../.venv/bin/activate
```

### בנייה

```
dbt build                              models + tests + seeds, בסדר ה-DAG
dbt run                                מודלים בלבד
dbt test                               tests בלבד
```

### בחירה לפי שכבה

```
dbt build --select staging
dbt build --select marts
dbt build --select marts.insurance
dbt build --exclude marts
```

### בחירה לפי גרף — `+` הוא כיוון הזרימה

```
dbt build --select fct_claims          המודל בלבד
dbt build --select +fct_claims         הוא + כל ה-upstream
dbt build --select fct_claims+         הוא + כל ה-downstream
dbt build --select +fct_claims+        שני הכיוונים
dbt build --select stg_crm__policies+  שיניתי stage — מה נשבר בהמשך
dbt build --select source:crm+         הכל מהמקור ולמטה
```

### אחרי כשל

```
dbt retry                                              ממשיך מנקודת הכשל
dbt build --select result:error+ --state ./target      מה שנפל + התלויים בו
```

### Slim CI — מה ש-dbt Cloud מריץ ב-PR

```
dbt build --select state:modified+ --defer --state ./target
```

בונה רק את מה שהשתנה ואת ה-downstream שלו, ומושך את השאר מ-prod.

### שונות

```
dbt compile                            מרנדר SQL בלי לגעת בנתונים
dbt docs generate                      בונה את הגרף והתיעוד
dbt show --select fct_claims --limit 5 הצצה בלי לכתוב
dbt run --full-refresh                 בונה incremental מאפס
```

---

## מלכודות שנתקלנו בהן

### `dbt build --empty` מוחק נתונים

`--empty` **אינו** dry run. הוא בונה את האובייקטים באמת, רק עוטף כל מקור
ב-`where false limit 0`:

```sql
select * from (select * from RAW.CRM.customers where false limit 0)
```

התוצאה: הטבלאות והviews נדרסים בגרסאות ריקות. מצוין לבדיקת סכימה והרשאות
בלי לשרוף credits — **הרסני על prod**.

- ב-dev: להריץ בחופשיות, ואז `dbt build` רגיל להחזרת הנתונים.
- ב-prod: לעולם לא. שם ה-dry run הוא `dbt compile`, או job נפרד בסביבת CI.

### Snowsight מוודא את כל ה-worksheet לפני שהוא מריץ משפט אחד

סקריפט שיוצר סכימה ואז כותב אליה נכשל **כולו** ולא יוצר כלום, כי
`insert into raw.crm.customers` לא עובר validation בזמן שהטבלה עוד לא קיימת.
השגיאה מדווחת בשורה שנראית לא קשורה.

לכן `00_seed_raw_crm.sql` צריך לרוץ **משפט אחרי משפט**, לא כ-batch.

### שמות שמורים

`rows` היא מילה שמורה ב-Snowflake. `count(*) as rows` נכשל; `as row_count` עובד.

---

## מצב נוכחי — מה לא אמיתי כאן

**`RAW.CRM` נוצר ביד.** אין שכבת EL בחשבון התרגול הזה, אז
`snowflake/00_seed_raw_crm.sql` מייצר את הסכימה, שלוש הטבלאות ו-36 שורות דמה.
הנתונים בנויים כדי להפעיל את הלוגיקה: `status` מגיע ב-case מעורב ועם רווחים,
לפוליסה אחת אין `end_date`, ותביעה אחת הוגשה אחרי שהפוליסה פגה.

**מבנה העמודות ב-`_crm__sources.yml` הוא הנחה.** הוא לא נקרא ממערכת מקור
אמיתית. כשמגיעים נתונים אמיתיים צריך ליישר גם אותו וגם את שכבת ה-stage.

**סביבות.** מקומית ה-target הוא `ANALYTICS.DBT_GIL`, ומכאן dbt יוצר
`DBT_GIL_STAGING` ו-`DBT_GIL_MARTS`. ב-dbt Cloud ה-schema בפרופיל שונה, אז
הוא יבנה סט משלו ולא ידרוס את המקומי — זה בדיוק המנגנון שמפריד dev מ-prod.

---

## אימות

```bash
pbcopy < ../snowflake/01_verify.sql
```

שש שאילתות: ספירות ב-RAW, מה dbt בנה ומאיזה סוג, החותמת האחידה, הניקוי
שהשכבה עשתה (raw מול staged זה לצד זה), שאילתה עסקית, והדגל שתופס את התביעה
מחוץ לתקופת התוקף.

מצב אחרון שנבדק — `dbt build` → `PASS=48 ERROR=0`:

| | סוג | שורות |
|---|---|---|
| `RAW.CRM.{customers,policies,claims}` | TABLE | 8 / 12 / 16 |
| `DBT_GIL_STAGING.STG_CRM__*` | VIEW | — |
| `DBT_GIL_MARTS.DIM_CUSTOMERS` | TABLE | 8 |
| `DBT_GIL_MARTS.DIM_POLICIES` | TABLE | 12 |
| `DBT_GIL_MARTS.FCT_CLAIMS` | TABLE | 16 |
| `int_claims_enriched` | ephemeral | לא קיים כאובייקט |
