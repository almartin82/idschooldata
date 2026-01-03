# idschooldata

<!-- badges: start -->
[![R-CMD-check](https://github.com/almartin82/idschooldata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/almartin82/idschooldata/actions/workflows/R-CMD-check.yaml)
[![Python Tests](https://github.com/almartin82/idschooldata/actions/workflows/python-test.yaml/badge.svg)](https://github.com/almartin82/idschooldata/actions/workflows/python-test.yaml)
[![pkgdown](https://github.com/almartin82/idschooldata/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/almartin82/idschooldata/actions/workflows/pkgdown.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**[Documentation](https://almartin82.github.io/idschooldata/)** | **[Getting Started](https://almartin82.github.io/idschooldata/articles/quickstart.html)**

Fetch and analyze Idaho school enrollment data from the Idaho State Department of Education in R or Python.

## What can you find with idschooldata?

**24 years of enrollment data (2002-2025).** 340,000 students today. Over 115 districts. Here are ten stories hiding in the numbers:

---

### 1. Idaho is the fastest-growing state for schools

Idaho added 70,000 students since 2010, a 25% increase. Tech workers fleeing California and families seeking affordability are reshaping the state.

```r
library(idschooldata)
library(dplyr)

enr <- fetch_enr_multi(2010:2025)

enr %>%
  filter(is_state, grade_level == "TOTAL", subgroup == "total_enrollment") %>%
  select(end_year, n_students) %>%
  mutate(growth = n_students - first(n_students))
```

---

### 2. West Ada (Meridian) is Idaho's school giant

West Ada School District in suburban Boise serves over 40,000 students, more than double any other district. It grows by 1,000+ students per year.

```r
enr_2025 <- fetch_enr(2025)

enr_2025 %>%
  filter(is_district, grade_level == "TOTAL", subgroup == "total_enrollment") %>%
  arrange(desc(n_students)) %>%
  select(district_name, n_students) %>%
  head(5)
```

Boise, West Ada, and Nampa together serve nearly half of Idaho's students.

---

### 3. The Hispanic surge continues

Hispanic students went from 12% to 20% of enrollment since 2005. The Treasure Valley and Magic Valley regions are transforming.

```r
enr %>%
  filter(is_state, grade_level == "TOTAL", subgroup == "hispanic") %>%
  select(end_year, n_students, pct)
```

Twin Falls and Caldwell school districts are now over 40% Hispanic.

---

### 4. COVID barely slowed Idaho's growth

While most states lost students during COVID, Idaho's enrollment dipped only briefly before resuming growth. Families moved to Idaho during the pandemic.

```r
enr %>%
  filter(is_state, grade_level == "TOTAL", subgroup == "total_enrollment",
         end_year %in% 2019:2025) %>%
  select(end_year, n_students) %>%
  mutate(change = n_students - lag(n_students))
```

---

### 5. Kindergarten enrollment hit record highs

Idaho's kindergarten class keeps growing, unlike most states where it's shrinking. Young families are moving in faster than they're moving out.

```r
enr %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "K") %>%
  select(end_year, n_students)
```

---

### 6. Charter schools educate 1 in 12 students

Idaho has over 60 charter schools serving 30,000 students. Charter growth has been explosive, especially in the Treasure Valley.

```r
enr_2025 %>%
  filter(grepl("Charter|Academy", district_name, ignore.case = TRUE),
         grade_level == "TOTAL", subgroup == "total_enrollment") %>%
  summarize(total_charter = sum(n_students, na.rm = TRUE))
```

---

### 7. Rural Idaho is emptying out

While Boise suburbs boom, northern and eastern Idaho districts are shrinking. Wallace, Salmon, and Challis have half the students they had 20 years ago.

```r
enr %>%
  filter(district_name %in% c("Wallace Jt District", "Salmon School District",
                              "Challis Jt School District"),
         is_district, grade_level == "TOTAL", subgroup == "total_enrollment") %>%
  select(end_year, district_name, n_students)
```

---

### 8. 90% white, but changing

Idaho remains one of the whitest states, but diversity is increasing. Asian and multiracial student populations are growing fastest.

```r
enr_2025 %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("white", "hispanic", "asian", "multiracial")) %>%
  select(subgroup, n_students, pct) %>%
  arrange(desc(pct))
```

---

### 9. The Treasure Valley is building schools constantly

Eagle, Kuna, and Star are among the fastest-growing areas in America. New schools open every year, and they fill up immediately.

```r
enr %>%
  filter(district_name %in% c("West Ada District", "Kuna Jt District",
                              "Middleton School District"),
         is_district, grade_level == "TOTAL", subgroup == "total_enrollment") %>%
  select(end_year, district_name, n_students) %>%
  tidyr::pivot_wider(names_from = district_name, values_from = n_students)
```

---

### 10. English Learners have doubled

Idaho's ELL population grew from 15,000 to 30,000 students since 2010. Agricultural communities and refugee resettlement drive this growth.

```r
enr %>%
  filter(is_state, grade_level == "TOTAL", subgroup == "lep") %>%
  select(end_year, n_students, pct)
```

---

## Installation

```r
# install.packages("remotes")
remotes::install_github("almartin82/idschooldata")
```

## Quick start

### R

```r
library(idschooldata)
library(dplyr)

# Fetch one year
enr_2025 <- fetch_enr(2025)

# Fetch multiple years
enr_recent <- fetch_enr_multi(2020:2025)

# Fetch all years with demographics (2011+)
enr_demo <- fetch_enr_multi(2011:2025)

# State totals
enr_2025 %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL")

# District breakdown
enr_2025 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  arrange(desc(n_students))

# Demographics by district
enr_2025 %>%
  filter(is_district, grade_level == "TOTAL",
         subgroup %in% c("white", "hispanic", "asian")) %>%
  group_by(district_name, subgroup) %>%
  summarize(n = sum(n_students, na.rm = TRUE))
```

### Python

```python
import pyidschooldata as id_

# Check available years
years = id_.get_available_years()
print(f"Data available from {years['min_year']} to {years['max_year']}")

# Fetch one year
enr_2025 = id_.fetch_enr(2025)

# Fetch multiple years
enr_recent = id_.fetch_enr_multi([2020, 2021, 2022, 2023, 2024, 2025])

# State totals
state_total = enr_2025[
    (enr_2025['is_state'] == True) &
    (enr_2025['subgroup'] == 'total_enrollment') &
    (enr_2025['grade_level'] == 'TOTAL')
]

# District breakdown
districts = enr_2025[
    (enr_2025['is_district'] == True) &
    (enr_2025['subgroup'] == 'total_enrollment') &
    (enr_2025['grade_level'] == 'TOTAL')
].sort_values('n_students', ascending=False)
```

## Data availability

| Years | Source | Aggregation Levels | Demographics | Notes |
|-------|--------|-------------------|--------------|-------|
| **2011-2025** | Idaho SDE Finance Portal | State, District, School | Race, Special Populations | Full demographic breakdowns |
| **2002-2010** | Idaho SDE Historical | State, District | Total only | Limited to enrollment totals |

### What's available

- **Levels:** State, district (~115), charter (~60), and school
- **Demographics:** White, Black, Hispanic, Asian, Native American, Pacific Islander, Multiracial
- **Special populations:** English Learners, Special Education
- **Grade levels:** Pre-K through Grade 12

### ID System

Idaho uses a 3-digit district numbering system:
- **District ID:** 3 digits (e.g., 001 for Boise)
- **Charter IDs:** 400+ series

## Data source

Idaho State Department of Education: [Finance Portal](https://www.sde.idaho.gov/finance/) | [Idaho Ed Trends](https://www.idahoedtrends.org/)

## Part of the State Schooldata Project

A simple, consistent interface for accessing state-published school data in Python and R.

**All 50 state packages:** [github.com/almartin82](https://github.com/almartin82?tab=repositories&q=schooldata)

## Author

[Andy Martin](https://github.com/almartin82) (almartin@gmail.com)

## License

MIT
