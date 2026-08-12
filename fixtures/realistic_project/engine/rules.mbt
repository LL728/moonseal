///|
pub fn retry_allowed(attempt : Int, max_attempts : Int) -> Bool {
  attempt >= 0 && attempt < max_attempts
}

///|
pub fn backoff_ms(attempt : Int) -> Int {
  if attempt <= 0 {
    0
  } else if attempt > 6 {
    64000
  } else {
    1000 * (1 << attempt)
  }
}
