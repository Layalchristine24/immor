# validate_listings() rejects missing columns

    Code
      validate_listings(bad)
    Condition
      Error in `validate_listings()`:
      ! Type stability violated
      Caused by error in `ensure_type()`:
      ! Columns missing
      i Columns `portal_id`, `url`, `scraped_at`, `transaction_type`, `property_type`, `title`, `description`, `price`, `price_unit`, `currency`, `rooms`, `area_m2`, `floor`, `address_street`, `address_zip`, `address_city`, `address_canton`, `latitude`, ..., `is_furnished`, and `energy_label` not found in data

