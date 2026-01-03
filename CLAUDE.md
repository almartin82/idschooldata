## CRITICAL DATA SOURCE RULES

**NEVER use Urban Institute API, NCES CCD, or ANY federal data source** — the entire point of these packages is to provide STATE-LEVEL data directly from state DOEs. Federal sources aggregate/transform data differently and lose state-specific details. If a state DOE source is broken, FIX IT or find an alternative STATE source — do not fall back to federal data.

---


# Claude Code Instructions

### GIT COMMIT POLICY
- Commits are allowed
- NO Claude Code attribution, NO Co-Authored-By trailers, NO emojis
- Write normal commit messages as if a human wrote them

---

## Local Testing Before PRs (REQUIRED)

**PRs will not be merged until CI passes.** Run these checks locally BEFORE opening a PR:

### CI Checks That Must Pass

| Check | Local Command | What It Tests |
|-------|---------------|---------------|
| R-CMD-check | `devtools::check()` | Package builds, tests pass, no errors/warnings |
| Python tests | `pytest tests/test_pyidschooldata.py -v` | Python wrapper works correctly |
| pkgdown | `pkgdown::build_site()` | Documentation and vignettes render |

### Quick Commands

```r
# R package check (required)
devtools::check()

# Python tests (required)
system("pip install -e ./pyidschooldata && pytest tests/test_pyidschooldata.py -v")

# pkgdown build (required)
pkgdown::build_site()
```

### Pre-PR Checklist

Before opening a PR, verify:
- [ ] `devtools::check()` — 0 errors, 0 warnings
- [ ] `pytest tests/test_pyidschooldata.py` — all tests pass
- [ ] `pkgdown::build_site()` — builds without errors
- [ ] Vignettes render (no `eval=FALSE` hacks)

---

## LIVE Pipeline Testing

This package includes `tests/testthat/test-pipeline-live.R` with LIVE network tests.

### Test Categories:
1. URL Availability - HTTP 200 checks
2. File Download - Verify actual file (not HTML error)
3. File Parsing - readxl/readr succeeds
4. Column Structure - Expected columns exist
5. get_raw_enr() - Raw data function works
6. Data Quality - No Inf/NaN, non-negative counts
7. Aggregation - State total > 0
8. Output Fidelity - tidy=TRUE matches raw

### Running Tests:
```r
devtools::test(filter = "pipeline-live")
```

See `state-schooldata/CLAUDE.md` for complete testing framework documentation.

---

## Idaho SDE Data Sources (Verified January 2026)

### Primary Enrollment Data URL
**Historical Enrollment by District/Charter** (WORKING)
- URL: `https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx`
- Size: ~500KB
- Format: Excel (xlsx)
- Years: 1995-1996 through 2025-2026
- Contents: District/charter enrollment by grade level
- Structure:
  - Skip 4 header rows
  - Column 1 (`#`): District ID number
  - Column 2 (`School District or Charter School`): Entity name (fill-down format)
  - Column 3 (`Year`): School year in format "YYYY-YYYY" (e.g., "2024-2025")
  - Column 4 (`Membership`): Total enrollment
  - Columns 5-18: Grade-level enrollment (Preschool, K, 1st-12th)

### Additional Data Files (WORKING)
1. **Historical Enrollment by Building**
   - URL: `https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-Building-1.xlsx`
   - Size: ~6MB
   - Building-level enrollment data

2. **Current Enrollment by District/Charter**
   - URL: `https://www.sde.idaho.gov/wp-content/uploads/2025/12/Enrollment-by-District-and-Charter-School.xlsx`
   - Latest year only

3. **Historical State Enrollment by Grade**
   - URL: `https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-State-Enrollment-by-Grade.xlsx`
   - Statewide totals by grade

### Known Broken URLs (404 as of January 2026)
The following old URL patterns no longer work:
- `https://www.sde.idaho.gov/finance/files/attendance-enrollment/historical/*`
- `https://www.sde.idaho.gov/finance/files/attendance-enrollment/enrollment/*`

### Where to Find Updated URLs
If URLs break again, check:
1. Finance portal: https://www.sde.idaho.gov/finance/
2. Look for "Attendance and Enrollment" section
3. Files are now in `/wp-content/uploads/YYYY/MM/` format

### Data Characteristics
- Year format: "YYYY-YYYY" (e.g., "2024-2025")
- Fill-down format: District names only appear on first row per entity
- State totals: First block of rows contains "STATE OF IDAHO - TOTALS"
- ~190+ districts/charters per year
- Total state enrollment: ~310,000-320,000 students

### Demographics
Race/ethnicity data is NOT included in the main enrollment file. Available through:
- Idaho Report Card: https://idahoreportcard.org/


---

## Git Workflow (REQUIRED)

### Feature Branch + PR + Auto-Merge Policy

**NEVER push directly to main.** All changes must go through PRs with auto-merge:

```bash
# 1. Create feature branch
git checkout -b fix/description-of-change

# 2. Make changes, commit
git add -A
git commit -m "Fix: description of change"

# 3. Push and create PR with auto-merge
git push -u origin fix/description-of-change
gh pr create --title "Fix: description" --body "Description of changes"
gh pr merge --auto --squash

# 4. Clean up stale branches after PR merges
git checkout main && git pull && git fetch --prune origin
```

### Branch Cleanup (REQUIRED)

**Clean up stale branches every time you touch this package:**

```bash
# Delete local branches merged to main
git branch --merged main | grep -v main | xargs -r git branch -d

# Prune remote tracking branches
git fetch --prune origin
```

### Auto-Merge Requirements

PRs auto-merge when ALL CI checks pass:
- R-CMD-check (0 errors, 0 warnings)
- Python tests (if py{st}schooldata exists)
- pkgdown build (vignettes must render)

If CI fails, fix the issue and push - auto-merge triggers when checks pass.

