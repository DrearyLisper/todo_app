import gleam/json
import gleeunit
import shared/todos.{TodoItem}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn todo_list_round_trip_test() {
  let items = [
    TodoItem(label: "Buy milk", done: False),
    TodoItem(label: "Walk the dog", done: True),
  ]

  let encoded = items |> todos.todo_list_to_json() |> json.to_string()

  let assert Ok(decoded) = json.parse(encoded, todos.todo_list_decoder())

  assert decoded == items
}
