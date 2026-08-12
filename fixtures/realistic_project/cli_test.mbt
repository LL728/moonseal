///|
test "accepts a bounded batch" {
  assert_true(accept_batch(4, 8))
  assert_false(accept_batch(0, 8))
  assert_false(accept_batch(9, 8))
}
