source(here::here("R", "00_config.R"))
library(arrow)
library(here)
library(dplyr)

weather <- read_parquet(PATH_WEATHER_OUT)
dust <- read_parquet(PATH_DUST_OUT)

print(head(weather))
print(head(dust))

all <- inner_join(weather, dust, by = c('city', 'country', 'lat', 'lon', 'date')) |>
  mutate(pm_ratio = pm2_5_mean / pm10_mean)

write.csv(all, file = PATH_ALL_OUT, quote = FALSE, row.names = FALSE)
