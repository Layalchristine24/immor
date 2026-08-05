# Isolate the whole test run from the real HTTP cache directory. Individual
# tests that exercise cache behaviour override these with withr::local_envvar().
Sys.setenv(
  IMMOR_NO_CACHE = "1",
  R_USER_CACHE_DIR = tempfile("immor-tests-")
)

mock_flatfox_listing <- function(
  pk = 12345,
  public_title = "Bahnhofstrasse 10, 8001 Zurich - CHF 1500 excl. utilities per month",
  short_title = "Sunny 3.5 room apartment",
  price_display = "1500",
  number_of_rooms = "3.5",
  surface_living = "85",
  offer_type = "RENT",
  object_category = "APARTMENT",
  street = "Bahnhofstrasse 10",
  zipcode = "8001",
  city = "Zurich",
  latitude = 47.3769,
  longitude = 8.5417
) {
  list(
    pk = pk,
    url = paste0("/en/flat/", pk),
    public_title = public_title,
    short_title = short_title,
    description = "A lovely apartment in the city center.",
    price_display = price_display,
    number_of_rooms = number_of_rooms,
    surface_living = surface_living,
    offer_type = offer_type,
    object_category = object_category,
    street = street,
    zipcode = zipcode,
    city = city,
    latitude = latitude,
    longitude = longitude,
    floor = 2L,
    images = c(8716673L, 8716674L),
    moving_date = "2026-04-01",
    year_built = NULL,
    is_furnished = FALSE
  )
}
