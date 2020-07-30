test_that("Tasks can be executed and produce results", {
  # set the max number of workers to ensure that 
  # tasks run in parallel
  options(executor.max_workers = 8L)

  # number of tasks to run
  N <- 10
  indices <- 1:N


  # results of tasks will be written out here
  out <- numeric(10)

  for(i in indices) {
    task <- delayed_eval(i, i = i)
    submit_task(task, default_executor_queue, function(value, i) {
      out[[i]] <<- value
    })
  }

  # execute all tasks while recording the 
  # number of active workers
  n_active_workers <- 0L

  while(executor_has_pending_tasks()) {
    executor_step()
    
    n_active_workers <- max(
      executor_active_worker_count(), 
      n_active_workers
    )
  }

  expect_equal(out, indices)
  expect_true(n_active_workers > 1L)
})


test_that("Tasks that have differnt runtimes can be executed and produce results", {
  # set the max number of workers to ensure that 
  # tasks run in parallel
  options(executor.max_workers = 8L)

  # number of tasks to run
  N <- 10
  indices <- 1:N

  # results of tasks will be written out here
  out <- numeric(10)

  for(i in indices) {
    task <- delayed_eval({
      Sys.sleep(runif(1, 0.5, 5))
      i
    }, i = i)
    submit_task(task, default_executor_queue, function(value, i) {
      out[[i]] <<- value
    })
  }

  # execute all tasks while recording the 
  # number of active workers
  n_active_workers <- 0L

  while(executor_has_pending_tasks()) {
    executor_step()
    
    n_active_workers <- max(
      executor_active_worker_count(), 
      n_active_workers
    )
  }

  expect_equal(out, indices)
  expect_true(n_active_workers > 1L)
})


