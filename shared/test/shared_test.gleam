import gleam/json
import gleeunit
import shared/todos.{TodoItem}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn todo_list_round_trip_test() {
  let items = [
    TodoItem(id: "1", label: "Buy milk", done: False, due: "2026-08-30"),
    TodoItem(id: "2", label: "Walk the dog", done: True, due: "2026-08-31"),
  ]

  let encoded = items |> todos.todo_list_to_json() |> json.to_string()

  let assert Ok(decoded) = json.parse(encoded, todos.todo_list_decoder())

  assert decoded == items
}

pub fn todo_list_decodes_legacy_items_test() {
  let encoded = "[{\"label\": \"Buy milk\", \"done\": false}]"

  let assert Ok(decoded) = json.parse(encoded, todos.todo_list_decoder())

  assert decoded
    == [
      TodoItem(id: "", label: "Buy milk", done: False, due: ""),
    ]
}
