# the internal executor environment
executor_state <- rlang::new_environment(
  list(
    # currently active workers (callr sessions)
    workers = list(),
    # list of task queues in their schedule order
    queues = list(),
    # the strictly incremental task id
    next_task_id  = 1L,
    # the map of task ids to internal task objects
    task_list = list()
  )
)

get_task_by_id <- function(id) executor_state$task_list[[id]]

generate_task_id <- function() {
  id <- executor_state$next_task_id
  executor_state$next_task_id <- id + 1L

  id
}