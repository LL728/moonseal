///|
test "retry boundaries are explicit" {
  assert_true(retry_allowed(0, 3))
  assert_true(retry_allowed(2, 3))
  assert_false(retry_allowed(3, 3))
  assert_false(retry_allowed(-1, 3))
}

///|
test "backoff is capped" {
  assert_eq(backoff_ms(0), 0)
  assert_eq(backoff_ms(3), 8000)
  assert_eq(backoff_ms(7), 64000)
}
