# pkgdown Build Issues

## Network Connectivity Issue (2026-01-01)

The pkgdown build is failing due to network timeouts when trying to reach CRAN/Bioconductor servers to check package links.

### Error Details
```
Error in `httr2::req_perform()`:
! Failed to perform HTTP request.
Caused by error in `curl::curl_fetch_memory()`:
! Timeout was reached [cloud.r-project.org]:
Connection timed out after 10001 milliseconds
```

### Root Cause
- Network connectivity to `cloud.r-project.org` and `bioconductor.org` is failing
- This is an infrastructure/network issue, not a code problem
- The pkgdown build tries to check if the package is on CRAN/Bioconductor as part of building the home sidebar

### Resolution Options
1. Wait for network connectivity to be restored
2. Run the build from a machine with working network access
3. Use GitHub Actions for pkgdown builds (avoids local network issues)

### Notes
- No vignettes exist in this package
- The package code and structure appear correct
- This issue will resolve itself when network connectivity is available
