#' Create a weck-aeby portal
#'
#' Constructs a portal object for
#' [weck-aeby.ch](https://www.weck-aeby.ch), a Swiss real
#' estate agency using the CasaWP WordPress plugin. Data is
#' scraped from server-rendered HTML pages.
#'
#' @return An `immor_portal` object for weck-aeby.
#'
#' @examples
#' portal_weckaeby()
#' @export
portal_weckaeby <- function() {
  out <- new_portal(
    name = "weckaeby",
    base_url = "https://www.weck-aeby.ch"
  )
  out$buy_path <- "/acheter/"
  out$rent_path <- "/louer/"
  out
}

#' @export
fetch_listings.immor_portal_weckaeby <- function(
  portal,
  query,
  max_pages = 5L,
  ...
) {
  base_url <- portal$base_url
  pages <- list(
    list(path = portal$buy_path, type = "buy"),
    list(path = portal$rent_path, type = "rent")
  )

  all_listings <- list()

  for (page in pages) {
    page_url <- paste0(base_url, page$path)
    links <- weckaeby_fetch_links(page_url)

    if (length(links) == 0) next

    cli::cli_inform(
      "Found {length(links)} listing{?s} on {.url {page_url}}."
    )

    for (link in links) {
      listing <- tryCatch(
        {
          html <- weckaeby_fetch_detail(link)
          raw <- list(
            html = html,
            transaction_type = page$type,
            url = link
          )
          parse_listing(portal, raw)
        },
        error = function(e) {
          cli::cli_warn(
            "Failed to parse {.url {link}}: {conditionMessage(e)}"
          )
          NULL
        },
      )
      if (!is.null(listing)) {
        all_listings <- c(all_listings, list(listing))
      }
    }
  }

  result <- dplyr::bind_rows(all_listings)

  if (nrow(result) == 0) {
    return(immor_schema())
  }

  validate_listings(result)
}

#' @export
parse_listing.immor_portal_weckaeby <- function(portal, raw_listing) {
  html <- raw_listing$html
  transaction_type <- raw_listing$transaction_type %||% "rent"
  detail_url <- raw_listing$url %||% NA_character_

  details <- weckaeby_parse_details_block(html)

  title <- html |>
    rvest::html_element(".title") |>
    rvest::html_text2()
  if (is.na(title)) title <- NA_character_

  maps_link <- html |> rvest::html_element("a[href*='google.com/maps']")
  address_text <- if (!is.na(maps_link)) {
    rvest::html_text2(maps_link)
  } else {
    NA_character_
  }
  addr <- weckaeby_parse_address(address_text)

  price_text <- weckaeby_detail_value(details, "Prix")
  if (is.na(price_text)) {
    price_text <- weckaeby_detail_value(details, "Loyer")
  }
  price <- weckaeby_parse_price(price_text)
  if (!is.na(price) && price == 0) price <- NA_real_

  rooms_text <- weckaeby_detail_value(details, "Nombre de pi")
  rooms <- if (!is.na(rooms_text)) {
    suppressWarnings(as.numeric(gsub("[^0-9.]", "", rooms_text)))
  } else {
    NA_real_
  }

  area_text <- weckaeby_detail_value(details, "Surface habitable|Wohnfl")
  area_m2 <- if (!is.na(area_text)) {
    suppressWarnings(as.numeric(gsub("[^0-9.]", "", area_text)))
  } else {
    NA_real_
  }

  year_text <- weckaeby_detail_value(details, "construction|Baujahr")
  year_built <- if (!is.na(year_text)) {
    suppressWarnings(as.integer(gsub("[^0-9]", "", year_text)))
  } else {
    NA_integer_
  }

  desc_container <- html |>
    rvest::html_element("div.detail .container")
  description <- if (!is.na(desc_container)) {
    paras <- desc_container |> rvest::html_elements("p")
    texts <- paras |> rvest::html_text2()
    texts <- texts[nzchar(trimws(texts))]
    if (length(texts) > 0) paste(texts, collapse = "\n") else NA_character_
  } else {
    NA_character_
  }

  img_urls <- html |>
    rvest::html_elements(
      "img[src*='casagateway'], img[src*='flatfox.ch/thumb']"
    ) |>
    rvest::html_attr("src")

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

  avail_text <- weckaeby_detail_value(details, "Disponibilit")
  available_from <- if (!is.na(avail_text)) {
    tryCatch(
      as.Date(avail_text, format = "%d.%m.%Y"),
      error = \(e) as.Date(NA)
    )
  } else {
    as.Date(NA)
  }

  price_unit <- if (transaction_type == "buy") "total" else "monthly"

  tibble::tibble(
    portal = "weckaeby",
    portal_id = weckaeby_extract_pk(detail_url),
    url = detail_url,
    scraped_at = Sys.time(),
    transaction_type = transaction_type,
    property_type = NA_character_,
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

# --- Internal helpers (no roxygen) -----------------------------------------

weckaeby_fetch_links <- function(page_url) {
  req <- httr2::request(page_url) |>
    immor_request(delay = 10)

  resp <- httr2::req_perform(req)
  html <- httr2::resp_body_html(resp)

  links <- html |>
    rvest::html_elements("a[href*='/objet/']") |>
    rvest::html_attr("href")

  links <- ifelse(
    startsWith(links, "http"),
    links,
    paste0("https://www.weck-aeby.ch", links)
  )

  pks <- vapply(links, weckaeby_extract_pk, character(1))
  keep <- !duplicated(pks) & !is.na(pks)
  links[keep]
}

weckaeby_fetch_detail <- function(detail_url) {
  req <- httr2::request(detail_url) |>
    immor_request(delay = 10)

  resp <- httr2::req_perform(req)
  httr2::resp_body_html(resp)
}

weckaeby_parse_price <- function(text) {
  if (is.null(text) || is.na(text)) return(NA_real_)
  text <- trimws(text)
  if (grepl("sur demande|auf Anfrage|on request", text, ignore.case = TRUE)) {
    return(NA_real_)
  }
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
  m <- regmatches(text, regexec("^(.+),\\s*(\\d{4})\\s+(.+)$", text))[[1]]
  if (length(m) == 4) {
    return(list(street = m[2], zip = m[3], city = m[4]))
  }
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

weckaeby_parse_details_block <- function(html) {
  details_div <- html |> rvest::html_element("div.details")
  if (is.na(details_div)) return(list())

  text <- rvest::html_text2(details_div)
  lines <- strsplit(text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

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

  result <- list()
  i <- 1
  while (i < length(lines)) {
    if (
      nchar(lines[i]) <= 50 &&
        grepl(label_pattern, lines[i], ignore.case = TRUE)
    ) {
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

weckaeby_detail_value <- function(details, pattern) {
  for (nm in names(details)) {
    if (grepl(pattern, nm, ignore.case = TRUE)) {
      return(details[[nm]])
    }
  }
  NA_character_
}
