# reap-finished-tasks

Status: Draft · Pass 0 · Updated 2026-11-18 · Linear: OPS-694

**EDD: no** Verified by the suite plus the two tests below.

> What this is: gwproactor's `add_task` keeps every task it is given for
> the life of the process and never hears a task fail. This design makes
> it drop a finished task and log a raised one.

## The defect

`Proactor.add_task` (`gwproactor/proactor_implementation.py`) appends
to `self._tasks`, a list the proactor walks only in `join` at shutdown.
Two things follow for any actor that launches one task per unit of
work:

- The list grows by one task object per launch for the life of the
  process. A scada relay adds an `_attempt_command` task per I2C command
  on main today, and a GPIO relay adds one per actuation on the plant
  seam branch.
- Nothing awaits or inspects the task, so an exception inside it
  surfaces only as Python's "Task exception was never retrieved" when
  the object is collected. In operation that is silence.

## The change

`add_task` attaches a done callback. The callback removes the task from
`self._tasks`; if the task raised, it logs the exception with the
task's name. Cancellation is not an error and is not logged. `join`
keeps walking whatever is still in the list, which is now the tasks
still running.

Two tests in gwproactor: a task that completes is gone from the list
after one loop turn; a task that raises is logged with its name and is
gone from the list.

Each actor's own reporting of a failed task (glitch, report to a boss)
stays the actor's; this design gives the proactor the baseline that no
task fails unseen.

## Do this next

Cut `jm/reap-finished-tasks` from gridworks-proactor main, write the
two tests, then the callback.
