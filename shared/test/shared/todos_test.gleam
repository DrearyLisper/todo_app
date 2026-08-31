import gleam/list
import gleeunit
import shared/todos.{
  type TodoItem, TodoItem, due_label, group_by_due, sort_by_due,
}

pub fn main() -> Nil {
  gleeunit.main()
}

fn item(id: String, label: String, due: String) -> TodoItem {
  TodoItem(id: id, label: label, done: False, due: due)
}

pub fn sort_by_due_orders_closest_first_test() {
  let items = [
    item("a", "far", "2026-09-10"),
    item("b", "near", "2026-08-30"),
    item("c", "mid", "2026-09-02"),
  ]

  let sorted = sort_by_due(items)

  assert list.map(sorted, fn(i) { i.due })
    == ["2026-08-30", "2026-09-02", "2026-09-10"]
}

pub fn group_by_due_splits_on_date_change_test() {
  let items = [
    item("a", "one", "2026-08-30"),
    item("b", "two", "2026-08-30"),
    item("c", "three", "2026-09-01"),
  ]

  let groups = group_by_due(items)

  assert list.length(groups) == 2
  let assert Ok(#(first_due, first_rows)) = list.first(groups)
  assert first_due == "2026-08-30"
  assert list.length(first_rows) == 2
}

pub fn due_label_today_tomorrow_test() {
  assert due_label("2026-08-30", "2026-08-30") == "Today"
  assert due_label("2026-08-31", "2026-08-30") == "Tomorrow"
  assert due_label("2026-09-02", "2026-08-30") == "Sep 2"
}

pub fn due_label_handles_month_and_year_rollover_test() {
  assert due_label("2026-09-01", "2026-08-31") == "Tomorrow"
  assert due_label("2027-01-01", "2026-12-31") == "Tomorrow"
  assert due_label("2025-07-04", "2026-08-30") == "Jul 4, 2025"
}

pub fn due_label_handles_leap_year_test() {
  assert due_label("2028-03-01", "2028-02-29") == "Tomorrow"
  assert due_label("2027-03-01", "2027-02-28") == "Tomorrow"
  assert due_label("2028-03-02", "2028-02-28") == "Mar 2"
}
