#' @export
delayed_eval <- function(expr, ...) {
  # get the unevaluated closure body
  expr <- substitute(expr)

  # eagerly evaluate the capture list
  clist <- list(...)

  # return a delayed call object
  structure(list(
    # the unevaluated expression 
    expr = substitute(expr), 
    # the eagerly evaluated capture list
    capture_list = list(...)
  ), class="delayed_eval")
}

#' @export
print.delayed_eval <- function(x, ...) {
  cat("<delayed expression>\n")
  rlang::expr_print(x$expr)
}


as.function.delayed_eval <- function(x, ...) {
  as.function(c(x$capture_list, list(x$expr)), .GlobalEnv)
}
