test_that("delayed_eval() produces a correct delayed_eval object", {
  expr <- delayed_eval(a+b, a=1, b=2)

  expect_s3_class(expr, "delayed_eval")
  expect_equal(expr$expr, quote(a+b))
  expect_equal(expr$capture_list, list(a=1, b=2))
})

test_that("delayed_eval() can be converted to a function", {
  fun <- as.function(delayed_eval(a+b, a=1, b=2))
  
  expect_type(fun, "closure")
  expect_equal(fun, function(a=1, b=2) a + b)
  expect_equal(fun(), 3)
})


test_that("delayed_eval() captures it's context eagerly", {
  a <- 1
  fun <- as.function(delayed_eval(a+1, a=a))
  a <- 2
  
  expect_equal(fun(), 2)
})
