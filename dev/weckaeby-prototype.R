# Standalone prototype: scrape weck-aeby.ch listings
# Uses httr2 + rvest only. Returns tibble matching immor_schema() (28 columns).

library(httr2)
library(rvest)
library(tibble)
library(dplyr)

# --- Helpers ---------------------------------------------------------------

weckaeby_parse_price <- function(text) {
  if (is.null(text) || is.na(text)) return(NA_real_)
  text <- trimws(text)
  if (grepl("sur demande|auf Anfrage|on request", text, ignore.case = TRUE)) {
    return(NA_real_)
  }
  # Remove everything except digits (handles CHF, apostrophes, dots, dashes)
  num_str <- gsub("[^0-9]", "", text)
  if (nchar(num_str) == 0) return(NA_real_)
  as.numeric(num_str)
}

weckaeby_parse_address <- function(text) {
  if (is.null(text) || is.na(text) || !nzchar(trimws(text))) {
    return(list(
      street = NA_character_,
      zip = NA_character_,
      city = NA_character_
    ))
  }
  text <- trimws(text)
  # Pattern: "Route des Noisetiers 14, 1700 Fribourg"
  m <- regmatches(text, regexec("^(.+),\\s*(\\d{4})\\s+(.+)$", text))[[1]]
  if (length(m) == 4) {
    return(list(street = m[2], zip = m[3], city = m[4]))
  }
  # Fallback: just zip + city "1700 Fribourg"
  m2 <- regmatches(text, regexec("(\\d{4})\\s+(.+)$", text))[[1]]
  if (length(m2) == 3) {
    return(list(street = NA_character_, zip = m2[2], city = m2[3]))
  }
  list(street = text, zip = NA_character_, city = NA_character_)
}

weckaeby_extract_pk <- function(url) {
  m <- regmatches(url, regexec("pk=(\\d+)", url))[[1]]
  if (length(m) >= 2) m[2] else NA_character_
}

# Parse the label/value block from div.details text
# Returns a named list: label -> value
weckaeby_parse_details_block <- function(html) {
  details_div <- html |> html_element("div.details")
  if (is.na(details_div)) return(list())

  text <- html_text2(details_div)
  lines <- strsplit(text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

  # Known labels — values follow on the next line
  labels <- c(
    "Prix",
    "Loyer",
    "Charges",
    "Total",
    "Commune",
    "Niveau",
    "Nombre de pi",
    "Nombre de salle",
    "Ann.e de construction",
    "Ann.e de la derni.re",
    "Surface habitable",
    "Adapt.+enfants",
    "Balcon",
    "Ensoleil",
    "Calme",
    "Parking",
    "Machine",
    "S.che-linge",
    "Cat.gorie",
    "Type",
    "Etage",
    "R.f.rence",
    "Disponibilit"
  )
  label_pattern <- paste(labels, collapse = "|")

  # Only match lines that START with a known label (not titles/descriptions
  # that happen to contain label keywords like "pièces")
  result <- list()
  i <- 1
  while (i < length(lines)) {
    if (nchar(lines[i]) <= 50 && grepl(label_pattern, lines[i], ignore.case = TRUE)) {
      key <- lines[i]
      val <- if (i + 1 <= length(lines)) lines[i + 1] else NA_character_
      result[[key]] <- val
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  result
}

# Lookup a value from the details block by partial label match
weckaeby_detail_value <- function(details, pattern) {
  for (nm in names(details)) {
    if (grepl(pattern, nm, ignore.case = TRUE)) {
      return(details[[nm]])
    }
  }
  NA_character_
}

# --- Fetch listing page ----------------------------------------------------

fetch_weckaeby_links <- function(page_url) {
  cat("Fetching listing page:", page_url, "\n")
  resp <- request(page_url) |>
    req_headers(`User-Agent` = "immor R package (prototype)") |>
    req_perform()

  html <- resp |> resp_body_html()

  links <- html |>
    html_elements("a[href*='/objet/']") |>
    html_attr("href")

  # Make absolute
  links <- ifelse(
    startsWith(links, "http"),
    links,
    paste0("https://www.weck-aeby.ch", links)
  )

  # Deduplicate by pk value (same property appears with/without &ret= param)
  pks <- vapply(links, weckaeby_extract_pk, character(1))
  keep <- !duplicated(pks) & !is.na(pks)
  links[keep]
}

# --- Parse detail page -----------------------------------------------------

parse_weckaeby_detail <- function(detail_url, transaction_type) {
  cat("  Fetching detail:", detail_url, "\n")
  resp <- request(detail_url) |>
    req_headers(`User-Agent` = "immor R package (prototype)") |>
    req_throttle(rate = 1 / 10) |>
    req_perform()

  html <- resp |> resp_body_html()

  # Title: .title class
  title <- html |> html_element(".title") |> html_text2()
  if (is.na(title)) title <- NA_character_

  # Address from Google Maps link
  maps_link <- html |> html_element("a[href*='google.com/maps']")
  address_text <- if (!is.na(maps_link)) html_text2(maps_link) else NA_character_
  addr <- weckaeby_parse_address(address_text)

  # Parse label/value block
  details <- weckaeby_parse_details_block(html)

  # Price: "Prix" for buy, "Loyer" for rent
  price_text <- weckaeby_detail_value(details, "Prix")
  if (is.na(price_text)) {
    price_text <- weckaeby_detail_value(details, "Loyer")
  }
  price <- weckaeby_parse_price(price_text)
  # "CHF 0.-" means price not displayed

  if (!is.na(price) && price == 0) price <- NA_real_

  # Rooms
  rooms_text <- weckaeby_detail_value(details, "Nombre de pi")
  rooms <- if (!is.na(rooms_text)) {
    as.numeric(gsub("[^0-9.]", "", rooms_text))
  } else {
    NA_real_
  }

  # Area
  area_text <- weckaeby_detail_value(details, "Surface habitable|Wohnfl")
  area_m2 <- if (!is.na(area_text)) {
    as.numeric(gsub("[^0-9.]", "", area_text))
  } else {
    NA_real_
  }

  # Year built
  year_text <- weckaeby_detail_value(details, "construction|Baujahr")
  year_built <- if (!is.na(year_text)) {
    as.integer(gsub("[^0-9]", "", year_text))
  } else {
    NA_integer_
  }

  # Description: all content within div.detail excluding the details block
  desc_container <- html |> html_element("div.detail .container")
  description <- if (!is.na(desc_container)) {
    paras <- desc_container |> html_elements("p")
    texts <- paras |> html_text2()
    texts <- texts[nzchar(trimws(texts))]
    if (length(texts) > 0) paste(texts, collapse = "\n") else NA_character_
  } else {
    NA_character_
  }

  # Images (casagateway CDN or flatfox thumbnails)
  img_urls <- html |>
    html_elements("img[src*='casagateway'], img[src*='flatfox.ch/thumb']") |>
    html_attr("src")

  # Features
  has_balcony_text <- weckaeby_detail_value(details, "Balcon")
  has_balcony <- if (!is.na(has_balcony_text)) {
    grepl("Oui|Ja|Yes", has_balcony_text, ignore.case = TRUE)
  } else {
    NA
  }

  has_parking_text <- weckaeby_detail_value(details, "Parking")
  has_parking <- if (!is.na(has_parking_text)) {
    grepl("Oui|Ja|Yes", has_parking_text, ignore.case = TRUE)
  } else {
    NA
  }

  # Property type
  type_text <- weckaeby_detail_value(details, "Cat.gorie|Type")
  property_type <- if (!is.na(type_text)) {
    type_lower <- tolower(type_text)
    if (grepl("appart|wohnung", type_lower)) "apartment" else if (
      grepl("maison|haus|villa", type_lower)
    )
      "house" else if (grepl("commercial|gewerbe|bureau", type_lower)) "commercial" else if (
      grepl("parking|garage|depot", type_lower)
    )
      "parking" else "other"
  } else {
    NA_character_
  }

  # Availability
  avail_text <- weckaeby_detail_value(details, "Disponibilit")
  available_from <- if (!is.na(avail_text)) {
    # Format: "01.08.2026" (dd.mm.yyyy)
    tryCatch(
      as.Date(avail_text, format = "%d.%m.%Y"),
      error = \(e) as.Date(NA)
    )
  } else {
    as.Date(NA)
  }

  price_unit <- if (transaction_type == "buy") "total" else "monthly"

  tibble(
    portal = "weckaeby",
    portal_id = weckaeby_extract_pk(detail_url),
    url = detail_url,
    scraped_at = Sys.time(),
    transaction_type = transaction_type,
    property_type = property_type,
    title = title,
    description = description,
    price = price,
    price_unit = price_unit,
    currency = "CHF",
    rooms = rooms,
    area_m2 = area_m2,
    floor = NA_integer_,
    address_street = addr$street,
    address_zip = addr$zip,
    address_city = addr$city,
    address_canton = NA_character_,
    latitude = NA_real_,
    longitude = NA_real_,
    images = list(img_urls),
    available_from = available_from,
    year_built = year_built,
    has_balcony = has_balcony,
    has_parking = has_parking,
    has_elevator = NA,
    is_furnished = NA,
    energy_label = NA_character_,
  )
}

# --- Main ------------------------------------------------------------------

scrape_weckaeby <- function() {
  pages <- list(
    list(url = "https://www.weck-aeby.ch/acheter/", type = "buy"),
    list(url = "https://www.weck-aeby.ch/louer/", type = "rent")
  )

  all_listings <- list()

  for (page in pages) {
    links <- fetch_weckaeby_links(page$url)
    cat("Found", length(links), "unique listings on", page$url, "\n")

    for (link in links) {
      listing <- tryCatch(
        parse_weckaeby_detail(link, page$type),
        error = function(e) {
          cat("  ERROR parsing", link, ":", conditionMessage(e), "\n")
          NULL
        }
      )
      if (!is.null(listing)) {
        all_listings <- c(all_listings, list(listing))
      }
    }
  }

  result <- bind_rows(all_listings)
  cat("\nDone:", nrow(result), "listings scraped\n")
  result
}

# Run it
listings <- scrape_weckaeby()
print(listings, n = 30)
cat("\n=== Key fields check ===\n")
cat("Titles non-NA:", sum(!is.na(listings$title)), "/", nrow(listings), "\n")
cat("Prices non-NA:", sum(!is.na(listings$price)), "/", nrow(listings), "\n")
cat("Rooms non-NA:", sum(!is.na(listings$rooms)), "/", nrow(listings), "\n")
cat("Address non-NA:", sum(!is.na(listings$address_city)), "/", nrow(listings), "\n")
cat("Images > 0:", sum(vapply(listings$images, length, integer(1)) > 0), "/", nrow(listings), "\n")
cat("Year built non-NA:", sum(!is.na(listings$year_built)), "/", nrow(listings), "\n")
cat("Available from non-NA:", sum(!is.na(listings$available_from)), "/", nrow(listings), "\n")
cat("Description non-NA:", sum(!is.na(listings$description)), "/", nrow(listings), "\n")
cat("\n=== Sample data ===\n")
listings |>
  select(title, price, rooms, address_city, year_built, available_from) |>
  print(n = 20)
