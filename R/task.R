#' @export
`print.executor-task` <- function(x, ...) {
  cat("Task #", x, " [", task_status(x), "]\n", sep="")
}

#' @export
task_status <- function(id) {
  get_task_by_id(id)$status
}