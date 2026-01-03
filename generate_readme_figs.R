#!/usr/bin/env Rscript
# Generate README figures for idschooldata

library(ggplot2)
library(dplyr)
library(scales)
devtools::load_all(".")

# Create figures directory
dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

# Theme
theme_readme <- function() {
  theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold", size = 16),
      plot.subtitle = element_text(color = "gray40"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}

colors <- c("total" = "#2C3E50", "white" = "#3498DB", "black" = "#E74C3C",
            "hispanic" = "#F39C12", "asian" = "#9B59B6")

# Get available years (handles both vector and list return types)
years <- get_available_years()
if (is.list(years)) {
  max_year <- years$max_year
  min_year <- years$min_year
} else {
  max_year <- max(years)
  min_year <- min(years)
}

# Fetch data
message("Fetching data...")
enr <- fetch_enr_multi(max(min_year, 2010):max_year)
enr_recent <- fetch_enr_multi((max_year - 9):max_year)

# 1. Enrollment growth (state total)
message("Creating enrollment growth chart...")
state_trend <- enr %>%
  filter(is_state, grade_level == "TOTAL", subgroup == "total_enrollment")

p <- ggplot(state_trend, aes(x = end_year, y = n_students)) +
  geom_line(linewidth = 1.5, color = colors["total"]) +
  geom_point(size = 3, color = colors["total"]) +
  scale_y_continuous(labels = comma, limits = c(0, NA)) +
  labs(title = "Idaho Public School Enrollment",
       subtitle = "Fastest-growing state: +70,000 students since 2010",
       x = "School Year", y = "Students") +
  theme_readme()
ggsave("man/figures/enrollment-growth.png", p, width = 10, height = 6, dpi = 150)

# 2. Hispanic growth
message("Creating Hispanic growth chart...")
hispanic <- enr %>%
  filter(is_state, grade_level == "TOTAL", subgroup == "hispanic")

p <- ggplot(hispanic, aes(x = end_year, y = pct * 100)) +
  geom_line(linewidth = 1.5, color = colors["hispanic"]) +
  geom_point(size = 3, color = colors["hispanic"]) +
  labs(title = "Hispanic Student Population in Idaho",
       subtitle = "From 12% to 20% since 2005",
       x = "School Year", y = "Percent of Students") +
  theme_readme()
ggsave("man/figures/hispanic-growth.png", p, width = 10, height = 6, dpi = 150)

# 3. Kindergarten trend
message("Creating kindergarten chart...")
k_trend <- enr_recent %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "K")

p <- ggplot(k_trend, aes(x = end_year, y = n_students)) +
  geom_line(linewidth = 1.5, color = colors["total"]) +
  geom_point(size = 3, color = colors["total"]) +
  scale_y_continuous(labels = comma) +
  labs(title = "Idaho Kindergarten Enrollment",
       subtitle = "Record highs as young families move in",
       x = "School Year", y = "Students") +
  theme_readme()
ggsave("man/figures/kindergarten.png", p, width = 10, height = 6, dpi = 150)

# 4. Treasure Valley growth (West Ada, Kuna, Middleton)
message("Creating Treasure Valley chart...")
treasure <- c("West Ada", "Kuna", "Middleton")

treasure_trend <- enr_recent %>%
  filter(is_district,
         grepl(paste(treasure, collapse = "|"), district_name, ignore.case = TRUE),
         subgroup == "total_enrollment", grade_level == "TOTAL")

p <- ggplot(treasure_trend, aes(x = end_year, y = n_students, color = district_name)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2.5) +
  scale_y_continuous(labels = comma) +
  labs(title = "Treasure Valley Growth",
       subtitle = "West Ada, Kuna, and Middleton building schools constantly",
       x = "School Year", y = "Students", color = "") +
  theme_readme()
ggsave("man/figures/treasure-valley.png", p, width = 10, height = 6, dpi = 150)

message("Done! Generated 4 figures in man/figures/")
